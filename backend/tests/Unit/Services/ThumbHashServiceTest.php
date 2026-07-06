<?php

namespace Tests\Unit\Services;

use App\Services\ThumbHashService;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Unit tests for {@see ThumbHashService}: it turns an image into a short
 * base64 ThumbHash and fails safe (null) for anything it can't hash.
 */
class ThumbHashServiceTest extends TestCase
{
    /** Writes a small real JPEG to a temp path and returns it. */
    private function tempImage(): string
    {
        $im = imagecreatetruecolor(400, 300);
        imagefill($im, 0, 0, imagecolorallocate($im, 30, 120, 200));
        imagefilledellipse($im, 200, 150, 160, 120, imagecolorallocate($im, 240, 200, 40));
        $path = tempnam(sys_get_temp_dir(), 'th_').'.jpg';
        imagejpeg($im, $path);
        imagedestroy($im);

        return $path;
    }

    #[Test]
    public function it_produces_a_thumbhash_string_for_a_real_image(): void
    {
        $path = $this->tempImage();
        $hash = (new ThumbHashService)->forImage($path);
        @unlink($path);

        $this->assertIsString($hash);
        $this->assertNotEmpty($hash);
    }

    #[Test]
    public function it_returns_null_for_a_missing_or_unreadable_file(): void
    {
        $this->assertNull((new ThumbHashService)->forImage('/no/such/file.jpg'));
    }

    #[Test]
    public function for_stored_image_skips_non_image_and_null_paths(): void
    {
        // A video (or any non-raster) path must not be hashed, and returns null
        // without touching disk — so a video send never pays for it.
        $this->assertNull((new ThumbHashService)->forStoredImage('uploads/chat/clip.mp4'));
        $this->assertNull((new ThumbHashService)->forStoredImage(null));
    }
}
