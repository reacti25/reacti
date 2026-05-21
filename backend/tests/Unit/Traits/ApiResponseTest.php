<?php

namespace Tests\Unit\Traits;

use App\Traits\ApiResponse;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Unit tests for the ApiResponse trait — the shared JSON envelope
 * builder. Exercised through an anonymous host class that uses the
 * trait.
 *
 * R7-1 made the error envelope symmetric: it now carries `success`
 * (the canonical flag) as well as the deprecated legacy `status`.
 */
class ApiResponseTest extends TestCase
{
    /** A throwaway object that mixes in the trait under test. */
    private function responder(): object
    {
        return new class
        {
            use ApiResponse;
        };
    }

    #[Test]
    public function error_envelope_carries_both_success_and_legacy_status(): void
    {
        $response = $this->responder()->error(['field' => 'bad'], 'Boom', 404);
        $body = $response->getData(true);

        // Canonical flag — present on both success and error paths.
        $this->assertArrayHasKey('success', $body);
        $this->assertFalse($body['success']);

        // Deprecated legacy alias — kept for older mobile builds.
        $this->assertArrayHasKey('status', $body);
        $this->assertFalse($body['status']);

        $this->assertSame('Boom', $body['message']);
        $this->assertSame(['field' => 'bad'], $body['data']);
        $this->assertSame(404, $body['code']);
        $this->assertSame(404, $response->getStatusCode());
    }

    #[Test]
    public function success_envelope_uses_the_success_flag(): void
    {
        $response = $this->responder()->success(['id' => 1], 'Done');
        $body = $response->getData(true);

        $this->assertTrue($body['success']);
        $this->assertArrayNotHasKey('status', $body);
        $this->assertSame('Done', $body['message']);
        $this->assertSame(200, $response->getStatusCode());
    }
}
