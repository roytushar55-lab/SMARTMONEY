using Microsoft.Extensions.DependencyInjection;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.Register;
using SmartMoney.Application.Features.Identity.Register;
using SmartMoney.Application.Contracts.Identity.Login;
using SmartMoney.Application.Features.Identity.Login;
using SmartMoney.Application.Contracts.Identity.VerifyEmailOtp;
using SmartMoney.Application.Features.Identity.VerifyEmailOtp;
using SmartMoney.Application.Contracts.Identity.ResendEmailOtp;
using SmartMoney.Application.Features.Identity.ResendEmailOtp;


namespace SmartMoney.Application.DependencyInjection;

public static class ApplicationDependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<RegisterUserValidator>();

        services.AddScoped<ICommandHandler<RegisterUserCommand, RegisterUserResponse>,RegisterUserCommandHandler>();

        services.AddScoped<LoginUserValidator>();

        services.AddScoped<ICommandHandler<LoginUserCommand, LoginUserResponse>,LoginUserCommandHandler>();

        services.AddScoped<VerifyEmailOtpValidator>();

        services.AddScoped<ICommandHandler<VerifyEmailOtpCommand, VerifyEmailOtpResponse>,VerifyEmailOtpCommandHandler>();

        services.AddScoped<ResendEmailOtpValidator>();

        services.AddScoped<ICommandHandler<ResendEmailOtpCommand, ResendEmailOtpResponse>,ResendEmailOtpCommandHandler>();

        return services;
    }
}