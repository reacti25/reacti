<?php

namespace Tests\Unit\Helpers;

use App\Helpers\Helper;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Every user upload goes through the `media` disk (AWS plan, step 1.1).
 *
 * On Hostinger the disk is the web root, so paths and URLs are byte-for-byte
 * what they were. On AWS it is S3 behind CloudFront. These tests pin both
 * faces plus the grep rule that keeps `asset()` away from stored media.
 */
class MediaDiskTest extends TestCase
{
    #[Test]
    public function uploads_land_on_the_media_disk_under_the_stored_relative_path(): void
    {
        Storage::fake('media');

        $image = Helper::uploadImage(UploadedFile::fake()->image('a.jpg'), 'profile');
        $video = Helper::fileUpload(UploadedFile::fake()->create('clip.mp4', 10, 'video/mp4'), 'chat', 'My Clip.mov');

        $this->assertMatchesRegularExpression('#^uploads/profile/\d+-\w{5}\.jpg$#', $image);
        $this->assertSame('uploads/chat/my-clip.mp4', $video);
        Storage::disk('media')->assertExists([$image, $video]);
    }

    #[Test]
    public function delete_removes_from_the_disk_and_reports_honestly(): void
    {
        Storage::fake('media');
        $path = Helper::fileUpload(UploadedFile::fake()->image('a.jpg'), 'chat', 'a');

        $this->assertTrue(Helper::deleteImage($path));
        Storage::disk('media')->assertMissing($path);
        $this->assertFalse(Helper::deleteImage($path), 'second delete finds nothing');
        $this->assertSame(1, Helper::deleteFiles([
            Helper::fileUpload(UploadedFile::fake()->image('b.jpg'), 'chat', 'b'),
            'https://reacti.io/uploads/chat/gone.jpg',
            '../etc/passwd',
            null,
        ]));
    }

    #[Test]
    public function local_media_url_is_exactly_what_asset_produced(): void
    {
        config(['app.url' => 'https://reacti.io', 'filesystems.disks.media.url' => 'https://reacti.io']);
        Storage::forgetDisk('media');

        // asset() used the request host; in production that is APP_URL, so
        // the two are identical there. Tests have no request, hence the literal.
        $this->assertSame('https://reacti.io/uploads/chat/a.jpg', media_url('uploads/chat/a.jpg'));
        $this->assertSame('https://x.test/uploads/old.jpg', media_url('https://x.test/uploads/old.jpg'), 'legacy full URLs pass through');
        $this->assertNull(media_url(null));
        $this->assertNull(media_url(''));
    }

    #[Test]
    public function s3_media_url_is_the_cloudfront_host(): void
    {
        config(['filesystems.disks.media' => [
            'driver' => 's3', 'key' => 'k', 'secret' => 's', 'region' => 'il-central-1',
            'bucket' => 'reacti-media', 'url' => 'https://media.reacti.io', 'throw' => true,
            'options' => ['ACL' => 'bucket-owner-full-control'],
        ]]);
        Storage::forgetDisk('media');

        $this->assertSame('https://media.reacti.io/uploads/chat/a.jpg', media_url('uploads/chat/a.jpg'));
    }

    #[Test]
    public function no_code_builds_media_urls_with_asset(): void
    {
        $offenders = collect(File::allFiles(app_path()))
            ->filter(fn ($f) => preg_match('/asset\(\s*(?!\'default\/)/', $f->getContents()))
            ->map(fn ($f) => $f->getRelativePathname())
            ->values()
            ->all();

        $this->assertSame([], $offenders, 'asset() is only for bundled public/default files; stored media uses media_url()');
    }

    #[Test]
    public function no_code_touches_uploads_on_the_local_filesystem(): void
    {
        $offenders = collect(File::allFiles(app_path()))
            ->filter(fn ($f) => preg_match('/public_path\(|\bunlink\(|->move\(/', $f->getContents()))
            ->map(fn ($f) => $f->getRelativePathname())
            ->values()
            ->all();

        $this->assertSame([], $offenders, 'media lives on the media disk, never on public_path()');
    }
}
