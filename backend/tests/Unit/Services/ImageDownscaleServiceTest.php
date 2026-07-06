<?php

namespace Tests\Unit\Services;

use App\Services\ImageDownscaleService;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Unit tests for {@see ImageDownscaleService}: it caps a large image's longest
 * edge, leaves small images alone, and fails safe for non-images.
 */
class ImageDownscaleServiceTest extends TestCase
{
    /** Writes a real JPEG of [$w]x[$h] under public/ and returns its abs path. */
    private function writePublicImage(string $rel, int $w, int $h): string
    {
        $abs = public_path($rel);
        @mkdir(dirname($abs), 0755, true);
        $im = imagecreatetruecolor($w, $h);
        imagefill($im, 0, 0, imagecolorallocate($im, 10, 100, 150));
        imagejpeg($im, $abs);
        imagedestroy($im);

        return $abs;
    }

    #[Test]
    public function it_downscales_a_large_image_within_the_cap(): void
    {
        $rel = 'uploads/test/big_'.uniqid().'.jpg';
        $abs = $this->writePublicImage($rel, 3000, 2000);

        (new ImageDownscaleService)->optimizeInPlace($rel);

        [$w, $h] = getimagesize($abs);
        @unlink($abs);

        $this->assertLessThanOrEqual(1600, $w);
        $this->assertLessThanOrEqual(1600, $h);
        // Aspect ratio preserved (3:2) → 1600x1067-ish.
        $this->assertGreaterThan(1500, $w);
    }

    #[Test]
    public function it_leaves_a_small_image_unchanged(): void
    {
        $rel = 'uploads/test/small_'.uniqid().'.jpg';
        $abs = $this->writePublicImage($rel, 400, 300);

        (new ImageDownscaleService)->optimizeInPlace($rel);

        [$w, $h] = getimagesize($abs);
        @unlink($abs);

        $this->assertSame(400, $w);
        $this->assertSame(300, $h);
    }

    #[Test]
    public function it_ignores_non_image_and_null_paths(): void
    {
        // Skipped by extension — no exception, no work.
        (new ImageDownscaleService)->optimizeInPlace('uploads/chat/clip.mp4');
        (new ImageDownscaleService)->optimizeInPlace(null);

        $this->addToAssertionCount(1);
    }
}
