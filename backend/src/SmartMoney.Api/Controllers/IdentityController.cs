using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
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
using SmartMoney.Application.Contracts.Identity.GoogleLogin;
using SmartMoney.Application.Features.Identity.GoogleLogin;

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

    private readonly ICommandHandler<LoginWithGoogleCommand,LoginUserResponse> _loginWithGoogleHandler;

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
        ICommandHandler<
            LoginWithGoogleCommand,
            LoginUserResponse> loginWithGoogleHandler)
    {
        _registerUserHandler = registerUserHandler;
        _loginUserHandler = loginUserHandler;
        _verifyEmailOtpHandler = verifyEmailOtpHandler;
        _resendEmailOtpHandler = resendEmailOtpHandler;
        _refreshTokenHandler = refreshTokenHandler;
        _forgotPasswordHandler = forgotPasswordHandler;
        _resetPasswordHandler = resetPasswordHandler;
        _loginWithGoogleHandler = loginWithGoogleHandler;
    }

    [AllowAnonymous]
    [HttpPost("register")]
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
            request.ReferralCode ?? string.Empty);

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
    [HttpPost("google-login")]
    [ProducesResponseType(typeof(LoginUserResponse),StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GoogleLogin([FromBody] GoogleLoginRequest request,CancellationToken cancellationToken)
    {
        var command = new LoginWithGoogleCommand(request.IdToken);

        try
        {
            LoginUserResponse response =
                await _loginWithGoogleHandler.HandleAsync(
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
}
