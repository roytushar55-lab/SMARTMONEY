using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Infrastructure.DependencyInjection;
using SmartMoney.Infrastructure.Persistence.Context;
using SmartMoney.Infrastructure.Persistence.Seed;
using SmartMoney.Application;
using SmartMoney.Application.DependencyInjection;
using SmartMoney.Api.Storage;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.Configure<SupabaseStorageOptions>(
    builder.Configuration.GetSection(SupabaseStorageOptions.SectionName));
builder.Services.AddHttpClient<IProfilePhotoStorage, SupabaseProfilePhotoStorage>();
builder.Services.AddHttpClient<ICatalogueMediaStorage, SupabaseCatalogueMediaStorage>();

// Add services to the container.
// Framework Services
builder.Services.AddControllers();
//builder.Services.AddOpenApi();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    // Bearer support so [Authorize] endpoints are testable from Swagger UI:
    // click Authorize and paste the raw JWT (no "Bearer " prefix needed).
    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.ParameterLocation.Header,
        Description = "Paste the accessToken from api/identity/login."
    });

    options.AddSecurityRequirement(document => new Microsoft.OpenApi.OpenApiSecurityRequirement
    {
        [new Microsoft.OpenApi.OpenApiSecuritySchemeReference("Bearer", document)] = new List<string>()
    });
});

// Browsers (the admin panel, Flutter web) may only call the API from the
// origins listed in Cors:AllowedOrigins. The native Android app is not
// subject to CORS. Any origin is allowed in Development only, because the
// Flutter web dev server picks a random localhost port on every run.
string[] allowedOrigins =
    builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];

builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterWeb", policy =>
    {
        if (allowedOrigins.Length > 0)
        {
            policy
                .WithOrigins(allowedOrigins)
                .AllowAnyHeader()
                .AllowAnyMethod();
        }
        else if (builder.Environment.IsDevelopment())
        {
            policy
                .AllowAnyOrigin()
                .AllowAnyHeader()
                .AllowAnyMethod();
        }
    });
});

// Behind a TLS-terminating proxy (DigitalOcean App Platform) the app only
// sees the proxy. Honour X-Forwarded-For/Proto so client IPs (rate limits,
// consent records) and the https scheme are correct. Trusting every proxy is
// only safe when the app is reachable solely through that proxy, so it is an
// explicit opt-in: set ForwardedHeaders__TrustAllProxies=true in production.
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;

    if (builder.Configuration.GetValue<bool>("ForwardedHeaders:TrustAllProxies"))
    {
        options.KnownIPNetworks.Clear();
        options.KnownProxies.Clear();
    }
});

// Brute-force and CPU-exhaustion protection. Password hashing is slow by
// design, so unthrottled login/OTP endpoints are also a cheap way to take the
// server down. Limits are per client IP and configurable.
int authPerMinute = builder.Configuration.GetValue("RateLimiting:AuthRequestsPerMinute", 20);
int otpPerTenMinutes = builder.Configuration.GetValue("RateLimiting:OtpRequestsPerTenMinutes", 10);

static string ClientKey(HttpContext context) =>
    context.Connection.RemoteIpAddress?.ToString() ?? "unknown";

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.OnRejected = async (context, cancellationToken) =>
    {
        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out TimeSpan retryAfter))
        {
            context.HttpContext.Response.Headers.RetryAfter =
                ((int)Math.Ceiling(retryAfter.TotalSeconds)).ToString();
        }

        await context.HttpContext.Response.WriteAsJsonAsync(
            new { message = "Too many requests. Please wait a moment and try again." },
            cancellationToken);
    };

    // Everything: a generous ceiling against scraping and floods.
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            ClientKey(context),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 300,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));

    // Login, register, token refresh.
    options.AddPolicy("auth", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            ClientKey(context),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = authPerMinute,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));

    // Anything that sends or checks an OTP code.
    options.AddPolicy("otp", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            ClientKey(context),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = otpPerTenMinutes,
                Window = TimeSpan.FromMinutes(10),
                QueueLimit = 0
            }));
});

// Uploads and webhooks are small; refuse anything big before buffering it.
builder.WebHost.ConfigureKestrel(options =>
    options.Limits.MaxRequestBodySize = 10 * 1024 * 1024);

var app = builder.Build();

// Must be first: everything after it (HTTPS redirect, rate limits, logging)
// should see the real client IP and scheme, not the proxy's.
app.UseForwardedHeaders();

// Never leak exception details: unhandled errors become a generic 500, and a
// lost concurrency race (two requests changing the same wallet) becomes 409.
app.UseExceptionHandler(errorApp => errorApp.Run(async context =>
{
    Exception? exception =
        context.Features.Get<IExceptionHandlerFeature>()?.Error;

    context.Response.ContentType = "application/json";

    if (exception is ConcurrencyConflictException)
    {
        context.Response.StatusCode = StatusCodes.Status409Conflict;
        await context.Response.WriteAsJsonAsync(new { message = exception.Message });
        return;
    }

    context.Response.StatusCode = StatusCodes.Status500InternalServerError;
    await context.Response.WriteAsJsonAsync(
        new { message = "Something went wrong. Please try again." });
}));

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

app.Use(async (context, next) =>
{
    var headers = context.Response.Headers;
    headers["X-Content-Type-Options"] = "nosniff";
    headers["X-Frame-Options"] = "DENY";
    headers["Referrer-Policy"] = "no-referrer";

    if (context.Request.Path.StartsWithSegments("/api"))
    {
        headers["Cache-Control"] = "no-store";
    }

    await next();
});

//if (app.Environment.IsDevelopment())
//{
//    app.MapOpenApi();
//}

// Fail fast at startup if OTP emails cannot be delivered (no SMTP outside
// Development), instead of failing the first real user's signup.
_ = app.Services.GetRequiredService<IEmailOtpSender>();

using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<SmartMoneyDbContext>();

    await RoleSeeder.SeedAsync(context);
    await CashbackSettingsSeeder.SeedAsync(context);
    await SuperAdminSeeder.SeedAsync(context, app.Configuration);

    // Erase the archived details of deleted accounts once their retention
    // period has passed. Runs on every start; there is no scheduled job yet.
    await context.DeletedUserArchives
        .Where(archive => archive.PurgeAfter <= DateTime.UtcNow)
        .ExecuteDeleteAsync();
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("FlutterWeb");

app.UseRateLimiter();

// Serves catalogue media (store logos/banners, offer images) from wwwroot,
// e.g. wwwroot/media/stores/myntra.png -> /media/stores/myntra.png.
// Registered after UseCors so the Flutter web client can decode the images.
app.UseStaticFiles();

// No HTTPS redirect in dev: browsers drop the Authorization header when a
// cross-origin request is 307-redirected from http://localhost:5256 to
// https://localhost:7056, which turns every [Authorize] endpoint into a 401.
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

app.Run();
