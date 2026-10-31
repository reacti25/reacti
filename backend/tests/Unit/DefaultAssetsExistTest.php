<?php

namespace Tests\Unit;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

/**
 * Guards that every `asset('default/...')` the code hands to the app names a
 * file that ships in `public/default`.
 *
 * Group chats pointed at `default/default_group.jpg`, which never existed, so
 * every group without a photo sent the app a 404 (found by the testing lab).
 */
class DefaultAssetsExistTest extends TestCase
{
    #[Test]
    public function every_default_asset_the_code_names_exists(): void
    {
        $root = __DIR__.'/../..';
        $missing = [];
        $files = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator("$root/app"));
        foreach ($files as $file) {
            if ($file->getExtension() !== 'php') {
                continue;
            }
            preg_match_all("/asset\('(default\/[^']+)'\)/", file_get_contents($file->getPathname()), $m);
            foreach ($m[1] as $asset) {
                if (! file_exists("$root/public/$asset")) {
                    $missing[] = "$asset (in {$file->getFilename()})";
                }
            }
        }

        $this->assertSame([], $missing);
    }
}
