using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using SmartMoney.Application.Abstractions.Affiliate;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Enums;
using SmartMoney.Infrastructure.Affiliate;
using SmartMoney.Infrastructure.Authentication;
using SmartMoney.Infrastructure.Persistence.Context;
using SmartMoney.Infrastructure.Persistence.Repositories;

namespace SmartMoney.Infrastructure.DependencyInjection;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        string connectionString =
            configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException(
                "Connection string 'DefaultConnection' was not found.");

        services.AddDbContext<SmartMoneyDbContext>(options =>
            options.UseNpgsql(connectionString));

        // Persistence
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IRoleRepository, RoleRepository>();
        services.AddScoped<IWalletRepository, WalletRepository>();
        services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
        services.AddScoped<IDeletedUserArchiveRepository, DeletedUserArchiveRepository>();
        services.AddScoped<IEmailVerificationOtpRepository,EmailVerificationOtpRepository>();
        services.AddScoped<IPasswordResetOtpRepository, PasswordResetOtpRepository>();
        services.AddScoped<ICategoryRepository, CategoryRepository>();
        services.AddScoped<IStoreRepository, StoreRepository>();
        services.AddScoped<IOfferRepository, OfferRepository>();
        services.AddScoped<IAffiliateClickRepository, AffiliateClickRepository>();
        services.AddScoped<IStoreAffiliateMappingRepository, StoreAffiliateMappingRepository>();
        services.AddScoped<IAffiliateNetworkRepository, AffiliateNetworkRepository>();
        services.AddScoped<IAffiliateConversionRepository, AffiliateConversionRepository>();
        services.AddScoped<ICashbackRepository, CashbackRepository>();
        services.AddScoped<ICashbackSettingsRepository, CashbackSettingsRepository>();
        services.AddScoped<INetworkCashbackSettingsRepository, NetworkCashbackSettingsRepository>();
        services.AddScoped<ICashbackRateOverrideRepository, CashbackRateOverrideRepository>();
        services.AddScoped<IWalletTransactionRepository, WalletTransactionRepository>();

        services.AddScoped<IUnitOfWork>(serviceProvider =>
            serviceProvider.GetRequiredService<SmartMoneyDbContext>());

        // Password hashing
        // Authentication services
        services.AddSingleton<IPasswordHasher, PasswordHasher>();
        services.AddSingleton<IOtpGenerator, SecureOtpGenerator>();
        // OTP delivery. SMTP when configured; the console sender (which prints
        // the code) is allowed in Development only. Anywhere else a missing
        // Email:Host is a startup error, not a silent "emails go nowhere".
        services.Configure<EmailOptions>(
            configuration.GetSection(EmailOptions.SectionName));

        services.AddSingleton<IEmailOtpSender>(serviceProvider =>
        {
            var emailOptions = serviceProvider
                .GetRequiredService<IOptions<EmailOptions>>().Value;

            if (!string.IsNullOrWhiteSpace(emailOptions.Host))
            {
                if (string.IsNullOrWhiteSpace(emailOptions.FromAddress))
                {
                    throw new InvalidOperationException(
                        "Email:FromAddress must be set when Email:Host is configured.");
                }

                return ActivatorUtilities
                    .CreateInstance<SmtpEmailOtpSender>(serviceProvider);
            }

            if (serviceProvider.GetRequiredService<IHostEnvironment>()
                .IsDevelopment())
            {
                return ActivatorUtilities
                    .CreateInstance<ConsoleEmailOtpSender>(serviceProvider);
            }

            throw new InvalidOperationException(
                "Email is not configured. Set Email:Host, Email:FromAddress, " +
                "Email:Username and Email:Password (outside Development OTP " +
                "codes cannot be delivered or printed).");
        });
        services.AddSingleton<IOtpHasher, SecureOtpHasher>();

        // Affiliate services
        services.AddSingleton<IAffiliateTokenGenerator, SecureAffiliateTokenGenerator>();

        // Provider client: the real Cuelinks client is registered only when an
        // API key is configured (User Secrets); otherwise the mock keeps the
        // full click -> tracked URL -> conversion loop working locally.
        services.Configure<CuelinksOptions>(
            configuration.GetSection(CuelinksOptions.SectionName));

        var cuelinksApiKey = configuration[$"{CuelinksOptions.SectionName}:ApiKey"];

        if (string.IsNullOrWhiteSpace(cuelinksApiKey))
        {
            services.AddSingleton<IAffiliateNetworkClient, MockAffiliateNetworkClient>();
        }
        else
        {
            services.AddHttpClient<IAffiliateNetworkClient, CuelinksAffiliateNetworkClient>();
        }




        // Read JWT settings
        JwtOptions jwtOptions =
            configuration
                .GetSection(JwtOptions.SectionName)
                .Get<JwtOptions>()
            ?? throw new InvalidOperationException(
                "JWT configuration was not found.");

        if (string.IsNullOrWhiteSpace(jwtOptions.Issuer))
        {
            throw new InvalidOperationException(
                "JWT issuer was not configured.");
        }

        if (string.IsNullOrWhiteSpace(jwtOptions.Audience))
        {
            throw new InvalidOperationException(
                "JWT audience was not configured.");
        }

        if (string.IsNullOrWhiteSpace(jwtOptions.SecretKey))
        {
            throw new InvalidOperationException(
                "JWT secret key was not configured.");
        }

        // HS256 is only as strong as its key: refuse short or guessable keys
        // rather than silently signing tokens with them.
        if (Encoding.UTF8.GetByteCount(jwtOptions.SecretKey) < 32)
        {
            throw new InvalidOperationException(
                "JWT secret key must be at least 32 bytes (use a long random value).");
        }

        // JWT services
        services.Configure<JwtOptions>(
            configuration.GetSection(JwtOptions.SectionName));

        services.AddSingleton<IJwtTokenGenerator, JwtTokenGenerator>();

        // JWT authentication
        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters =
                    new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidIssuer = jwtOptions.Issuer,

                        ValidateAudience = true,
                        ValidAudience = jwtOptions.Audience,

                        ValidateIssuerSigningKey = true,
                        IssuerSigningKey =
                            new SymmetricSecurityKey(
                                Encoding.UTF8.GetBytes(
                                    jwtOptions.SecretKey)),

                        ValidateLifetime = true,
                        ClockSkew = TimeSpan.Zero,

                        ValidAlgorithms = [SecurityAlgorithms.HmacSha256]
                    };

                // A signed token proves who the user *was* when it was
                // issued. Re-check the account on every request so a
                // deleted, deactivated or re-roled user stops working
                // immediately instead of when the token expires.
                options.Events = new JwtBearerEvents
                {
                    OnTokenValidated = async context =>
                    {
                        string? userIdClaim = context.Principal
                            ?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
                        string? roleClaim = context.Principal
                            ?.FindFirst(ClaimTypes.Role)?.Value;

                        if (!Guid.TryParse(userIdClaim, out Guid userId))
                        {
                            context.Fail("Invalid token subject.");
                            return;
                        }

                        var db = context.HttpContext.RequestServices
                            .GetRequiredService<SmartMoneyDbContext>();

                        var current = await db.Users
                            .AsNoTracking()
                            .Where(user => user.Id == userId)
                            .Select(user => new
                            {
                                user.IsActive,
                                user.Status,
                                Role = user.Role!.Name
                            })
                            .FirstOrDefaultAsync(
                                context.HttpContext.RequestAborted);

                        if (current is null ||
                            !current.IsActive ||
                            current.Status != UserStatus.Active)
                        {
                            context.Fail("Account is not active.");
                            return;
                        }

                        if (!string.Equals(
                                roleClaim,
                                current.Role.ToString(),
                                StringComparison.Ordinal))
                        {
                            context.Fail("Role changed; sign in again.");
                        }
                    }
                };
            });

        return services;
    }
}