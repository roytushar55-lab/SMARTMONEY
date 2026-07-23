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

namespace SmartMoney.Api.Controllers;

[ApiController]
[Route("api/identity")]
public sealed class IdentityController : ControllerBase
{
    private readonly ICommandHandler<RegisterUserCommand,RegisterUserResponse> _registerUserHandler;

    private readonly ICommandHandler<LoginUserCommand,LoginUserResponse> _loginUserHandler;

    private readonly ICommandHandler<VerifyEmailOtpCommand,VerifyEmailOtpResponse> _verifyEmailOtpHandler;

    private readonly ICommandHandler<ResendEmailOtpCommand,ResendEmailOtpResponse> _resendEmailOtpHandler;

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
            ResendEmailOtpResponse> resendEmailOtpHandler)
    {
        _registerUserHandler = registerUserHandler;
        _loginUserHandler = loginUserHandler;
        _verifyEmailOtpHandler = verifyEmailOtpHandler;
        _resendEmailOtpHandler = resendEmailOtpHandler;
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
}