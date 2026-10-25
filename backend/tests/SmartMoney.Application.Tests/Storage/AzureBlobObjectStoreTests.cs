using Azure;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using SmartMoney.Api.Storage;

namespace SmartMoney.Application.Tests.Storage;

public sealed class AzureBlobObjectStoreTests
{
    private static readonly Uri ContainerUri =
        new("https://smartmoneymedia.blob.core.windows.net/profile-images");

    private static Mock<BlobContainerClient> ContainerMock()
    {
        var container = new Mock<BlobContainerClient>();
        container.SetupGet(c => c.Uri).Returns(ContainerUri);
        container.SetupGet(c => c.Name).Returns("profile-images");
        return container;
    }

    [Fact]
    public async Task Upload_sets_content_type_and_cache_control_and_returns_public_url()
    {
        var container = ContainerMock();
        var blob = new Mock<BlobClient>();
        BlobUploadOptions? captured = null;

        blob.Setup(b => b.UploadAsync(
                It.IsAny<Stream>(),
                It.IsAny<BlobUploadOptions>(),
                It.IsAny<CancellationToken>()))
            .Callback<Stream, BlobUploadOptions, CancellationToken>(
                (_, options, _) => captured = options)
            .ReturnsAsync(Mock.Of<Response<BlobContentInfo>>());

        container.Setup(c => c.GetBlobClient("users/42/photo.png")).Returns(blob.Object);

        var store = new AzureBlobObjectStore(container.Object, publicBaseUrl: null, cacheControlSeconds: 600);

        (string publicUrl, string objectPath) = await store.UploadAsync(
            new MemoryStream([1, 2, 3]),
            "\\users/42/photo.png",
            "image/png",
            CancellationToken.None);

        Assert.Equal("users/42/photo.png", objectPath);
        Assert.Equal(
            "https://smartmoneymedia.blob.core.windows.net/profile-images/users/42/photo.png",
            publicUrl);
        Assert.NotNull(captured);
        Assert.Equal("image/png", captured!.HttpHeaders.ContentType);
        Assert.Equal("public, max-age=600", captured.HttpHeaders.CacheControl);
    }

    [Fact]
    public void Public_url_uses_the_cdn_origin_when_configured_and_escapes_segments()
    {
        var store = new AzureBlobObjectStore(
            ContainerMock().Object,
            publicBaseUrl: "https://media.smart-money.in/",
            cacheControlSeconds: 3600);

        string url = store.BuildPublicUrl("stores/my logo.png");

        Assert.Equal("https://media.smart-money.in/profile-images/stores/my%20logo.png", url);
    }

    [Theory]
    [InlineData(
        "https://smartmoneymedia.blob.core.windows.net/profile-images/users/42/photo%20one.png",
        "users/42/photo one.png")]
    [InlineData(
        "HTTPS://SMARTMONEYMEDIA.blob.core.windows.net/profile-images/users/42/a.png?sv=1",
        "users/42/a.png")]
    public void Public_url_inside_the_container_maps_back_to_the_blob_path(
        string publicUrl,
        string expectedPath)
    {
        var store = new AzureBlobObjectStore(ContainerMock().Object, null, 3600);

        bool found = store.TryGetObjectPath(publicUrl, out string? objectPath);

        Assert.True(found);
        Assert.Equal(expectedPath, objectPath);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("https://xyz.supabase.co/storage/v1/object/public/profile-images/users/42/a.png")]
    [InlineData("https://smartmoneymedia.blob.core.windows.net/catalogue-media/stores/a.png")]
    [InlineData("https://smartmoneymedia.blob.core.windows.net/profile-images/")]
    public void Urls_outside_the_container_are_never_treated_as_ours(string? publicUrl)
    {
        var store = new AzureBlobObjectStore(ContainerMock().Object, null, 3600);

        Assert.False(store.TryGetObjectPath(publicUrl, out string? objectPath));
        Assert.Null(objectPath);
    }

    [Fact]
    public async Task Profile_photo_delete_ignores_foreign_urls_and_swallows_storage_errors()
    {
        var container = ContainerMock();
        container.Setup(c => c.DeleteBlobIfExistsAsync(
                "users/42/old.png",
                It.IsAny<DeleteSnapshotsOption>(),
                It.IsAny<BlobRequestConditions>(),
                It.IsAny<CancellationToken>()))
            .ThrowsAsync(new RequestFailedException("boom"));

        var storage = new AzureBlobProfilePhotoStorage(
            new AzureBlobObjectStore(container.Object, null, 3600),
            NullLogger<AzureBlobProfilePhotoStorage>.Instance);

        // Foreign URL: nothing is called.
        await storage.DeleteByPublicUrlAsync(
            "https://xyz.supabase.co/storage/v1/object/public/profile-images/users/42/a.png",
            CancellationToken.None);

        container.Verify(c => c.DeleteBlobIfExistsAsync(
                It.IsAny<string>(),
                It.IsAny<DeleteSnapshotsOption>(),
                It.IsAny<BlobRequestConditions>(),
                It.IsAny<CancellationToken>()),
            Times.Never);

        // Our URL, storage failure: logged, not thrown.
        await storage.DeleteByPublicUrlAsync(
            "https://smartmoneymedia.blob.core.windows.net/profile-images/users/42/old.png",
            CancellationToken.None);

        container.Verify(c => c.DeleteBlobIfExistsAsync(
                "users/42/old.png",
                It.IsAny<DeleteSnapshotsOption>(),
                It.IsAny<BlobRequestConditions>(),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }
}
