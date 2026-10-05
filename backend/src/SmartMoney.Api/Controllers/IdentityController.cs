using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Api.Features.Identity.Register;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.Register;
using SmartMoney.Application.Features.Identity.Register;
using SmartMoney.Application.Contracts.Identity.Login;
using SmartMoney.Application.Features.Identity.Login;
using SmartMoney.Application.Contracts.Identity.VerifyEmailOtp;
using SmartMoney.Application.Features.Identity.VerifyEmailOtp;
using SmartMoney.Application.Contracts.Identity.ResendEmailOtp;
using SmartMoney.Application.Features.Identity.ResendEmailOtp;
using SmartMoney.Application.Contracts.Identity.RefreshToken;
using SmartMoney.Application.Features.Identity.RefreshToken;
using SmartMoney.Application.Contracts.Identity.ForgotPassword;
using SmartMoney.Application.Features.Identity.ForgotPassword;
using SmartMoney.Application.Contracts.Identity.ResetPassword;
using SmartMoney.Application.Features.Identity.ResetPassword;

namespace SmartMoney.Api.Controllers;

[ApiController]
[Route("api/identity")]
public sealed class IdentityController : ControllerBase
{
    private readonly ICommandHandler<RegisterUserCommand,RegisterUserResponse> _registerUserHandler;

    private readonly ICommandHandler<LoginUserCommand,LoginUserResponse> _loginUserHandler;

    private readonly ICommandHandler<VerifyEmailOtpCommand,VerifyEmailOtpResponse> _verifyEmailOtpHandler;

    private readonly ICommandHandler<ResendEmailOtpCommand,ResendEmailOtpResponse> _resendEmailOtpHandler;

    private readonly ICommandHandler<RefreshTokenCommand,RefreshTokenResponse> _refreshTokenHandler;

    private readonly ICommandHandler<ForgotPasswordCommand,ForgotPasswordResponse> _forgotPasswordHandler;

    private readonly ICommandHandler<ResetPasswordCommand,ResetPasswordResponse> _resetPasswordHandler;

    private readonly IRefreshTokenRepository _refreshTokenRepository;

    private readonly IUnitOfWork _unitOfWork;


    public IdentityController(
        ICommandHandler<
            RegisterUserCommand,
            RegisterUserResponse> registerUserHandler,
        ICommandHandler<
            LoginUserCommand,
            LoginUserResponse> loginUserHandler,
        ICommandHandler<
            VerifyEmailOtpCommand,
            VerifyEmailOtpResponse> verifyEmailOtpHandler,
        ICommandHandler<
            ResendEmailOtpCommand,
            ResendEmailOtpResponse> resendEmailOtpHandler,
        ICommandHandler<
            RefreshTokenCommand,
            RefreshTokenResponse> refreshTokenHandler,
        ICommandHandler<
            ForgotPasswordCommand,
            ForgotPasswordResponse> forgotPasswordHandler,
        ICommandHandler<
            ResetPasswordCommand,
            ResetPasswordResponse> resetPasswordHandler,
        IRefreshTokenRepository refreshTokenRepository,
        IUnitOfWork unitOfWork)
    {
        _registerUserHandler = registerUserHandler;
        _loginUserHandler = loginUserHandler;
        _verifyEmailOtpHandler = verifyEmailOtpHandler;
        _resendEmailOtpHandler = resendEmailOtpHandler;
        _refreshTokenHandler = refreshTokenHandler;
        _forgotPasswordHandler = forgotPasswordHandler;
        _resetPasswordHandler = resetPasswordHandler;
        _refreshTokenRepository = refreshTokenRepository;
        _unitOfWork = unitOfWork;
    }

    [AllowAnonymous]
    [HttpPost("register")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(typeof(RegisterUserResponse),StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Register([FromBody] RegisterUserRequest request,CancellationToken cancellationToken)
    {
        var command = new RegisterUserCommand(
            request.FullName,
            request.Email,
            request.PhoneNumber,
            request.Password,
            request.ReferralCode ?? string.Empty,
            request.AgeConfirmed,
            request.TermsAccepted,
            request.ConsentVersion,
            HttpContext.Connection.RemoteIpAddress?.ToString());

        try
        {
            RegisterUserResponse response =
                await _registerUserHandler.HandleAsync(
                    command,
                    cancellationToken);

            return StatusCode(
                StatusCodes.Status201Created,
                response);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new
            {
                message = exception.Message
            });
        }
        catch (InvalidOperationException exception)
        {
            return Conflict(new
            {
                message = exception.Message
            });
        }
    }

    [AllowAnonymous]
    [HttpPost("login")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(typeof(LoginUserResponse),StatusCodes.Status200OK)][ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Login([FromBody] LoginUserRequest request,CancellationToken cancellationToken)
    {
        var command = new LoginUserCommand(
            request.Email,
            request.Password);

        try
        {
            LoginUserResponse response =
                await _loginUserHandler.HandleAsync(
                    command,
                    cancellationToken);

            return Ok(response);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new
            {
                message = exception.Message
            });
        }
        catch (InvalidOperationException exception)
        {
            return Unauthorized(new
            {
                message = exception.Message
            });
        }
    }

    [AllowAnonymous]
    [HttpPost("verify-email-otp")]
    [EnableRateLimiting("otp")]
    [ProducesResponseType(typeof(VerifyEmailOtpResponse),StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> VerifyEmailOtp([FromBody] VerifyEmailOtpRequest request,CancellationToken cancellationToken)
    {
        var command = new VerifyEmailOtpCommand(
            request.Email,
            request.Otp);

        try
        {
            VerifyEmailOtpResponse response =
                await _verifyEmailOtpHandler.HandleAsync(
                    command,
                    cancellationToken);

            return Ok(response);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new
            {
                message = exception.Message
            });
        }
        catch (InvalidOperationException exception)
        {
            return BadRequest(new
            {
                message = exception.Message
            });
        }
    }

    [AllowAnonymous]
    [HttpPost("resend-email-otp")]
    [EnableRateLimiting("otp")]
    [ProducesResponseType(typeof(ResendEmailOtpResponse),StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ResendEmailOtp([FromBody] ResendEmailOtpRequest request,CancellationToken cancellationToken)
    {
        var command = new ResendEmailOtpCommand(
            request.Email);

        try
        {
            ResendEmailOtpResponse response =
                await _resendEmailOtpHandler.HandleAsync(
                    command,
                    cancellationToken);

            return Ok(response);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new
            {
                message = exception.Message
            });
        }
        catch (InvalidOperationException exception)
        {
            return BadRequest(new
            {
                message = exception.Message
            });
        }
    }

    [AllowAnonymous]
    [HttpPost("refresh-token")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(typeof(RefreshTokenResponse),StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request,CancellationToken cancellationToken)
    {
        var command = new RefreshTokenCommand(
            request.RefreshToken);

        try
        {
            RefreshTokenResponse response =
                await _refreshTokenHandler.HandleAsync(
                    command,
                    cancellationToken);

            return Ok(response);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new
            {
                message = exception.Message
            });
        }
        catch (InvalidOperationException exception)
        {
            return Unauthorized(new
            {
                message = exception.Message
            });
        }
    }

    [AllowAnonymous]
    [HttpPost("forgot-password")]
    [EnableRateLimiting("otp")]
    [ProducesResponseType(typeof(ForgotPasswordResponse),StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request,CancellationToken cancellationToken)
    {
        var command = new ForgotPasswordCommand(request.Email);

        try
        {
            ForgotPasswordResponse response =
                await _forgotPasswordHandler.HandleAsync(
                    command,
                    cancellationToken);

            // Always 200 with the same generic message, whether or not the
            // email belongs to an account — see the handler for why.
            return Ok(response);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new
            {
                message = exception.Message
            });
        }
    }

    [AllowAnonymous]
    [HttpPost("reset-password")]
    [EnableRateLimiting("otp")]
    [ProducesResponseType(typeof(ResetPasswordResponse),StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest request,CancellationToken cancellationToken)
    {
        var command = new ResetPasswordCommand(
            request.Email,
            request.Otp,
            request.NewPassword);

        try
        {
            ResetPasswordResponse response =
                await _resetPasswordHandler.HandleAsync(
                    command,
                    cancellationToken);

            return Ok(response);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new
            {
                message = exception.Message
            });
        }
        catch (InvalidOperationException exception)
        {
            return BadRequest(new
            {
                message = exception.Message
            });
        }
    }

    /// <summary>
    /// Server-side logout: revokes the given refresh token so a copy of it
    /// (backup, stolen device) stops working. Always 204 so it cannot be
    /// used to probe which tokens exist.
    /// </summary>
    [AllowAnonymous]
    [HttpPost("logout")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Logout([FromBody] RefreshTokenRequest request, CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            var token = await _refreshTokenRepository.GetByTokenAsync(
                request.RefreshToken.Trim(),
                cancellationToken);

            if (token is { IsRevoked: false })
            {
                token.Revoke();
                await _unitOfWork.SaveChangesAsync(cancellationToken);
            }
        }

        return NoContent();
    }
}
