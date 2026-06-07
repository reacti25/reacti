<?php

namespace Tests\Unit\Helpers;

use App\Helpers\Helper;
use Illuminate\Http\UploadedFile;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins that Helper::fileUpload() creates its upload directory non-world-writable
 * (backlog §1 / EP2 — the mkdir mode was 0777).
 *
 * POSIX-only: file-permission bits are not meaningful on Windows, so the test
 * skips there. It sets umask(0) so the requested mkdir mode is applied verbatim
 * — under the usual umask 022 both 0777 and 0755 collapse to 0755, hiding the
 * regression.
 */
class FileUploadDirPermsTest extends TestCase
{
    #[Test]
    public function file_upload_creates_a_non_world_writable_directory(): void
    {
        if (stripos(PHP_OS, 'WIN') === 0) {
            $this->markTestSkipped('POSIX permissions are not meaningful on Windows.');
        }

        $folder = 'perm_probe_'.uniqid();
        $dir = public_path("uploads/$folder");
        $oldUmask = umask(0);

        try {
            Helper::fileUpload(
                UploadedFile::fake()->image('probe.jpg'),
                $folder,
                'probe',
            );

            $this->assertDirectoryExists($dir);
            $this->assertSame(
                0755,
                fileperms($dir) & 0777,
                'upload directory must be 0755, not world-writable',
            );
        } finally {
            umask($oldUmask);
            foreach (glob("$dir/*") ?: [] as $file) {
                @unlink($file);
            }
            @rmdir($dir);
        }
    }
}
