using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.Register;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Abstractions.Authentication;

namespace SmartMoney.Application.Features.Identity.Register;

public sealed class RegisterUserCommandHandler
    : ICommandHandler<RegisterUserCommand, RegisterUserResponse>
{
    private readonly IUserRepository _userRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IPasswordHasher _passwordHasher;

    public RegisterUserCommandHandler(
        IUserRepository userRepository,
        IWalletRepository walletRepository,
        IPasswordHasher passwordHasher)
    {
        _userRepository = userRepository;
        _walletRepository = walletRepository;
        _passwordHasher = passwordHasher;
    }

    public async Task<RegisterUserResponse> HandleAsync(
        RegisterUserCommand command,
        CancellationToken cancellationToken)
    {
        throw new NotImplementedException();
    }
}