using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using SmartMoney.Application.Abstractions.Affiliate;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Persistence;
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
        services.AddScoped<IWalletTransactionRepository, WalletTransactionRepository>();

        services.AddScoped<IUnitOfWork>(serviceProvider =>
            serviceProvider.GetRequiredService<SmartMoneyDbContext>());

        // Password hashing
        // Authentication services
        services.AddSingleton<IPasswordHasher, PasswordHasher>();
        services.AddSingleton<IOtpGenerator, SecureOtpGenerator>();
        services.AddSingleton<IEmailOtpSender, ConsoleEmailOtpSender>();
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

        // JWT services
        services.Configure<JwtOptions>(
            configuration.GetSection(JwtOptions.SectionName));

        services.AddSingleton<IJwtTokenGenerator, JwtTokenGenerator>();

        // Google Sign-In: verifies ID tokens via Google's tokeninfo endpoint.
        // ClientId is intentionally not validated at startup like the JWT
        // options above — an empty value just means Google sign-in is
        // unconfigured, and GoogleIdTokenVerifier reports that per-request
        // instead of preventing the rest of the API from starting.
        services.Configure<GoogleAuthOptions>(
            configuration.GetSection(GoogleAuthOptions.SectionName));

        services.AddHttpClient<IGoogleIdTokenVerifier, GoogleIdTokenVerifier>(client =>
        {
            client.BaseAddress = new Uri("https://oauth2.googleapis.com/");
        });

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
                        ClockSkew = TimeSpan.Zero
                    };
            });

        return services;
    }
}