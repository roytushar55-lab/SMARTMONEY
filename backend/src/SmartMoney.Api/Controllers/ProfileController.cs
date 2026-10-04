using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Api.Storage;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.DeleteAccount;
using SmartMoney.Application.Features.Identity.DeleteAccount;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/profile")]
public sealed class ProfileController : ControllerBase
{
    private const long MaxProfilePhotoBytes = 2 * 1024 * 1024;

    private static readonly IReadOnlyDictionary<string, string>
        ProfilePhotoExtensions = new Dictionary<string, string>(
            StringComparer.OrdinalIgnoreCase)
        {
            ["image/jpeg"] = ".jpg",
            ["image/png"] = ".png",
            ["image/webp"] = ".webp"
        };

    private readonly IUserRepository _userRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IProfilePhotoStorage _profilePhotoStorage;
    private readonly ICommandHandler<DeleteAccountCommand, DeleteAccountResult> _deleteAccountHandler;

    public ProfileController(
        IUserRepository userRepository,
        IPasswordHasher passwordHasher,
        IUnitOfWork unitOfWork,
        IProfilePhotoStorage profilePhotoStorage,
        ICommandHandler<DeleteAccountCommand, DeleteAccountResult> deleteAccountHandler)
    {
        _userRepository = userRepository;
        _passwordHasher = passwordHasher;
        _unitOfWork = unitOfWork;
        _profilePhotoStorage = profilePhotoStorage;
        _deleteAccountHandler = deleteAccountHandler;
    }

    [HttpGet]
    [ProducesResponseType(typeof(ProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetProfile(
        CancellationToken cancellationToken)
    {
        User? user = await GetCurrentUserAsync(cancellationToken);

        if (user is null)
        {
            return NotFound(new
            {
                message = "Profile was not found."
            });
        }

        return Ok(ProfileResponse.FromUser(user));
    }

    [HttpPut("update-name")]
    [ProducesResponseType(typeof(ProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateName(
        [FromBody] UpdateProfileNameRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest(new
            {
                message = "Name is required."
            });
        }

        User? user = await GetCurrentUserAsync(cancellationToken);

        if (user is null)
        {
            return NotFound(new
            {
                message = "Profile was not found."
            });
        }

        user.UpdateFullName(request.Name);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return Ok(ProfileResponse.FromUser(user));
    }

    [HttpPut("change-password")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ChangePassword(
        [FromBody] ChangeProfilePasswordRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.NewPassword))
        {
            return BadRequest(new
            {
                message = "Password is required."
            });
        }

        User? user = await GetCurrentUserAsync(cancellationToken);

        if (user is null)
        {
            return NotFound(new
            {
                message = "Profile was not found."
            });
        }

        if (string.IsNullOrWhiteSpace(request.CurrentPassword) ||
            user.PasswordHash is null ||
            !_passwordHasher.Verify(
                request.CurrentPassword,
                user.PasswordHash))
        {
            // 400, not 401: the mobile client treats 401 as an expired
            // session and would try to refresh the token.
            return BadRequest(new
            {
                message = "Current password is incorrect."
            });
        }

        string passwordHash = _passwordHasher.Hash(request.NewPassword);

        user.ChangePasswordHash(passwordHash);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            message = "Password updated."
        });
    }

    [HttpPost("photo")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UploadPhoto(
        [FromForm] UploadProfilePhotoRequest request,
        CancellationToken cancellationToken)
    {
        IFormFile? photo = request.Photo;

        if (photo is null || photo.Length == 0)
        {
            return BadRequest(new
            {
                message = "Profile photo is required."
            });
        }

        if (photo.Length > MaxProfilePhotoBytes)
        {
            return BadRequest(new
            {
                message = "Profile photo must be 2 MB or smaller."
            });
        }

        string contentType = photo.ContentType ?? string.Empty;

        if (!ProfilePhotoExtensions.TryGetValue(
                contentType,
                out string? extension) ||
            string.IsNullOrWhiteSpace(extension))
        {
            return BadRequest(new
            {
                message = "Only JPG, PNG, and WebP images are supported."
            });
        }

        User? user = await GetCurrentUserAsync(cancellationToken);

        if (user is null)
        {
            return NotFound(new
            {
                message = "Profile was not found."
            });
        }

        string objectPath =
            $"users/{user.Id:N}/{Guid.NewGuid():N}{extension}";
        string? previousProfileImageUrl = user.ProfileImageUrl;

        await using Stream stream = photo.OpenReadStream();
        StoredProfilePhoto storedPhoto =
            await _profilePhotoStorage.UploadAsync(
                stream,
                objectPath,
                contentType,
                cancellationToken);

        user.UpdateProfileImageUrl(storedPhoto.PublicUrl);

        try
        {
            await _unitOfWork.SaveChangesAsync(cancellationToken);
        }
        catch
        {
            await _profilePhotoStorage.DeleteByPublicUrlAsync(
                storedPhoto.PublicUrl,
                cancellationToken);

            throw;
        }

        await _profilePhotoStorage.DeleteByPublicUrlAsync(
            previousProfileImageUrl,
            cancellationToken);

        return Ok(ProfileResponse.FromUser(user));
    }

    [HttpPost("delete-account")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> DeleteAccount(
        [FromBody] DeleteAccountRequest request,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(
                User.FindFirst(ClaimTypes.NameIdentifier)?.Value,
                out Guid userId))
        {
            return Unauthorized();
        }

        DeleteAccountResult result;

        try
        {
            result = await _deleteAccountHandler.HandleAsync(
                new DeleteAccountCommand(userId, request.Password),
                cancellationToken);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
        catch (KeyNotFoundException exception)
        {
            return NotFound(new { message = exception.Message });
        }
        catch (InvalidOperationException exception)
        {
            return Conflict(new { message = exception.Message });
        }

        // The account is already deleted at this point; a storage hiccup
        // must not turn that into a failed request.
        try
        {
            await _profilePhotoStorage.DeleteByPublicUrlAsync(
                result.PreviousProfileImageUrl,
                cancellationToken);
        }
        catch
        {
        }

        return NoContent();
    }

    private async Task<User?> GetCurrentUserAsync(
        CancellationToken cancellationToken)
    {
        string? userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (!Guid.TryParse(userId, out Guid id))
        {
            return null;
        }

        User? user = await _userRepository.GetByIdAsync(id, cancellationToken);

        return user is { Status: UserStatus.Deleted } ? null : user;
    }
}

public sealed record UpdateProfileNameRequest(string Name);

public sealed record ChangeProfilePasswordRequest(
    string CurrentPassword,
    string NewPassword);

public sealed record DeleteAccountRequest(string Password);

public sealed class UploadProfilePhotoRequest
{
    public IFormFile? Photo { get; set; }
}

public sealed record ProfileResponse(
    Guid Id,
    string FullName,
    string Email,
    string PhoneNumber,
    string? ProfileImageUrl,
    bool IsEmailVerified,
    string Status)
{
    public static ProfileResponse FromUser(User user)
    {
        return new ProfileResponse(
            user.Id,
            user.FullName,
            user.Email,
            user.MobileNumber,
            user.ProfileImageUrl,
            user.IsEmailVerified,
            user.Status.ToString());
    }
}
