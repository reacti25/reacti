<?php

namespace App\Services;

use Intervention\Image\Drivers\Gd\Driver;
use Intervention\Image\ImageManager;
use Thumbhash\Thumbhash;

use function Thumbhash\extract_size_and_pixels_with_gd;

/**
 * Computes a ThumbHash placeholder string for an uploaded image.
 *
 * A ThumbHash is a ~20-byte base64 string that decodes to a tiny blurred
 * preview of the image. The client renders it instantly while the real image
 * downloads, so a media message is never a blank box. Stored on the message
 * row and returned in the API so the app has it before the file arrives.
 *
 * Everything here is best-effort and fail-safe: any decode/encode problem
 * (unsupported format, corrupt file) returns null rather than throwing, so a
 * missing placeholder can never fail or slow a message send.
 */
class ThumbHashService
{
    /**
     * Raster image extensions GD can decode into pixels for hashing. HEIC/HEIF
     * are excluded (GD can't read them — [forImage] would just return null).
     */
    private const HASHABLE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

    /**
     * Returns the ThumbHash for a freshly stored upload given its
     * [$relativePath] (the `uploads/...` string from {@see Helper::fileUpload}),
     * or null when it isn't a hashable image. Convenience wrapper the send
     * services call so the extension check + path resolution live in one place.
     *
     * @param  string|null  $relativePath  Stored path (`uploads/chat/...`) or null.
     * @return string|null Base64 ThumbHash, or null when not a hashable image.
     */
    public function forStoredImage(?string $relativePath): ?string
    {
        if ($relativePath === null) {
            return null;
        }
        $ext = strtolower(pathinfo($relativePath, PATHINFO_EXTENSION));
        if (! in_array($ext, self::HASHABLE_EXTENSIONS, true)) {
            return null;
        }

        return $this->forImage(public_path($relativePath));
    }

    /**
     * Returns the ThumbHash string for the image at [$absolutePath], or null if
     * it can't be produced (not an image, unreadable, unsupported format).
     *
     * @param  string  $absolutePath  Absolute path to the just-stored image file.
     * @return string|null Base64 ThumbHash, or null on any failure.
     */
    public function forImage(string $absolutePath): ?string
    {
        try {
            if (! is_file($absolutePath)) {
                return null;
            }

            // ThumbHash requires an image no larger than 100x100; scale the
            // source down (keeping aspect) before extracting pixels, both to
            // satisfy that limit and to keep the per-pixel loop cheap.
            $image = (new ImageManager(new Driver))->read($absolutePath);
            $image->scaleDown(100, 100);
            $content = (string) $image->toJpeg(80);

            [$width, $height, $pixels] = extract_size_and_pixels_with_gd($content);

            return Thumbhash::convertHashToString(
                Thumbhash::RGBAToHash($width, $height, $pixels)
            );
        } catch (\Throwable $e) {
            // Placeholder is optional — never fail a send over it.
            return null;
        }
    }
}
