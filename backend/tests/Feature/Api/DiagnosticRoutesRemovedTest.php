<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * `/api/test-s3` was a "smoke test" endpoint that wrote/read/deleted
 * an object in the *production* S3 bucket on every call and leaked
 * the bucket URL. Even though it sat inside the auth:api group, any
 * authenticated user could trigger free abuse. Removed; this test
 * pins its absence.
 */
class DiagnosticRoutesRemovedTest extends TestCase
{
    #[Test]
    public function test_s3_route_is_not_registered(): void
    {
        // 404 (route gone), not 401 — the route is removed before the
        // auth middleware would have a chance to challenge.
        $this->getJson('/api/test-s3')->assertNotFound();
    }
}
