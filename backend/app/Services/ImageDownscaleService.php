<?php

namespace App\Services;

use Intervention\Image\Drivers\Gd\Driver;
use Intervention\Image\ImageManager;

/**
 * Downscales and re-encodes an uploaded chat image in place, so recipients
 * download a web-sized photo instead of a multi-megapixel phone original.
 *
 * Phone cameras produce 3–12 MB images; served raw they are slow to download
 * and never displayed larger than the screen. Capping the longest side at
 * {@see self::MAX_EDGE}px and re-encoding at {@see self::QUALITY} cuts the bytes
 * ~5–10× with no visible loss at chat sizes — the same thing WhatsApp does on
 * send. Overwrites the stored file (same path/extension), so no URL, response,
 * or client change is needed.
 *
 * Best-effort and fail-safe: any decode/encode problem, or a non-raster/animated
 * format, leaves the original untouched — a send is never blocked or lost.
 */
class ImageDownscaleService
{
    /** Longest-edge cap in pixels; plenty for full-screen viewing on any phone. */
    private const MAX_EDGE = 1600;

    /** JPEG/WebP re-encode quality — visually lossless at chat sizes. */
    private const QUALITY = 82;

    /**
     * Formats safe to downscale in place. GIF is excluded (re-encoding would
     * drop animation); video and everything else is skipped by extension.
     */
    private const OPTIMIZABLE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp'];

    /**
     * Downscales the stored image at [$relativePath] (the `uploads/...` string
     * from {@see Helper::fileUpload}) in place. No-op for a null path, a
     * non-optimizable format, or on any failure.
     */
    public function optimizeInPlace(?string $relativePath): void
    {
        if ($relativePath === null) {
            return;
        }
        $ext = strtolower(pathinfo($relativePath, PATHINFO_EXTENSION));
        if (! in_array($ext, self::OPTIMIZABLE_EXTENSIONS, true)) {
            return;
        }

        try {
            $absolutePath = public_path($relativePath);
            if (! is_file($absolutePath)) {
                return;
            }

            $image = (new ImageManager(new Driver))->read($absolutePath);
            // scaleDown never upsizes — a small image is left as-is; a large one
            // is fit within MAX_EDGE×MAX_EDGE keeping aspect ratio.
            $image->scaleDown(self::MAX_EDGE, self::MAX_EDGE);
            // Re-encode at the same extension (from the path) and overwrite.
            $image->save($absolutePath, quality: self::QUALITY);
        } catch (\Throwable $e) {
            // Best-effort — leave the original on any failure.
        }
    }
}
