using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Api.Storage;

namespace SmartMoney.Api.Controllers;

/// <summary>
/// Generic image upload for the admin content screens: upload once, get a
/// public URL back, paste that URL into the store/offer/category form. Keeps
/// image handling decoupled from the entity create/update endpoints.
/// </summary>
[ApiController]
[Authorize(Roles = "Admin,SuperAdmin")]
[Route("api/admin/media")]
public sealed class AdminMediaController : ControllerBase
{
    private const long MaxImageBytes = 5 * 1024 * 1024;

    private static readonly IReadOnlyDictionary<string, string> ImageExtensions =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["image/jpeg"] = ".jpg",
            ["image/png"] = ".png",
            ["image/webp"] = ".webp"
        };

    private readonly ICatalogueMediaStorage _catalogueMediaStorage;

    public AdminMediaController(ICatalogueMediaStorage catalogueMediaStorage)
    {
        _catalogueMediaStorage = catalogueMediaStorage;
    }

    [HttpPost("upload")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(UploadMediaResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<UploadMediaResponse>> Upload(
        [FromForm] UploadMediaRequest request,
        CancellationToken cancellationToken)
    {
        IFormFile? file = request.File;

        if (file is null || file.Length == 0)
        {
            return BadRequest(new { message = "An image file is required." });
        }

        if (file.Length > MaxImageBytes)
        {
            return BadRequest(new { message = "Image must be 5 MB or smaller." });
        }

        string contentType = file.ContentType ?? string.Empty;

        if (!ImageExtensions.TryGetValue(contentType, out string? extension))
        {
            return BadRequest(new { message = "Only JPG, PNG, and WebP images are supported." });
        }

        // "folder" hints where the image belongs (stores/offers/categories);
        // any other value falls back to a flat "misc" prefix rather than 400ing.
        string folder = request.Folder is "stores" or "offers" or "categories"
            ? request.Folder
            : "misc";

        string objectPath = $"{folder}/{Guid.NewGuid():N}{extension}";

        await using Stream stream = file.OpenReadStream();
        StoredCatalogueMedia stored = await _catalogueMediaStorage.UploadAsync(
            stream, objectPath, contentType, cancellationToken);

        return Ok(new UploadMediaResponse { Url = stored.PublicUrl });
    }
}

public sealed class UploadMediaRequest
{
    public IFormFile? File { get; set; }

    public string? Folder { get; set; }
}

public sealed class UploadMediaResponse
{
    public string Url { get; set; } = string.Empty;
}
