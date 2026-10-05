namespace SmartMoney.Api.Storage;

/// <summary>
/// Checks an upload's actual bytes against the image type it claims. The
/// Content-Type header is client-controlled, so trusting it alone would let
/// anyone store an HTML/SVG/script file in a public bucket under an image
/// name.
/// </summary>
public static class ImageSignature
{
    /// <summary>
    /// True when the stream starts with the magic bytes of <paramref name="contentType"/>
    /// (image/jpeg, image/png or image/webp). Leaves the stream at position 0.
    /// </summary>
    public static async Task<bool> MatchesAsync(
        Stream stream,
        string contentType,
        CancellationToken cancellationToken)
    {
        var header = new byte[12];
        int read = 0;

        while (read < header.Length)
        {
            int n = await stream.ReadAsync(
                header.AsMemory(read, header.Length - read),
                cancellationToken);

            if (n == 0)
            {
                break;
            }

            read += n;
        }

        if (stream.CanSeek)
        {
            stream.Position = 0;
        }

        return contentType.ToLowerInvariant() switch
        {
            "image/jpeg" => read >= 3 &&
                header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF,

            "image/png" => read >= 8 &&
                header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E &&
                header[3] == 0x47 && header[4] == 0x0D && header[5] == 0x0A &&
                header[6] == 0x1A && header[7] == 0x0A,

            "image/webp" => read >= 12 &&
                header[0] == (byte)'R' && header[1] == (byte)'I' &&
                header[2] == (byte)'F' && header[3] == (byte)'F' &&
                header[8] == (byte)'W' && header[9] == (byte)'E' &&
                header[10] == (byte)'B' && header[11] == (byte)'P',

            _ => false
        };
    }
}
