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

builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterWeb", policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

//if (app.Environment.IsDevelopment())
//{
//    app.MapOpenApi();
//}

using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<SmartMoneyDbContext>();

    await RoleSeeder.SeedAsync(context);
    await CashbackSettingsSeeder.SeedAsync(context);
    await SuperAdminSeeder.SeedAsync(context, app.Configuration);
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("FlutterWeb");

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
