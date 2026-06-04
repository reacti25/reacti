<?php

namespace Tests\Unit\Helpers;

use App\Helpers\Helper;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Unit tests for `Helper::deleteImage`.
 *
 * Pre-fix the empty-input branch contained `dd("jalis")` (a stray
 * debug call) which halted the whole request whenever the helper was
 * called with a null/empty path — e.g. deleting an entity that had no
 * avatar. This test pins the corrected behaviour: a clean no-op
 * `false` return, the call completes, and execution continues.
 */
class DeleteImageTest extends TestCase
{
    #[Test]
    public function deleteImage_returns_false_for_null_input_without_halting(): void
    {
        // The point of the test is that execution reaches the assertion.
        // Pre-fix, `dd("jalis")` would terminate the test run here.
        $this->assertFalse(Helper::deleteImage(null));
        $this->assertFalse(Helper::deleteImage(''));
    }

    #[Test]
    public function deleteImage_returns_false_when_file_does_not_exist(): void
    {
        $this->assertFalse(Helper::deleteImage('does/not/exist.jpg'));
    }
}
