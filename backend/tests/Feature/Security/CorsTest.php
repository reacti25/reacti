<?php

namespace Tests\Feature\Security;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins the CORS allowed-origins lockdown (backlog §1 / EP2).
 *
 * The config previously allowed any origin (`['*']`); it now restricts
 * cross-origin browser access to the known web origins. These tests prove a
 * disallowed origin is not reflected back while an allowed one is.
 */
class CorsTest extends TestCase
{
    /**
     * A request from an unknown origin must not have that origin echoed back
     * in the Access-Control-Allow-Origin header.
     */
    #[Test]
    public function disallowed_origin_is_not_reflected(): void
    {
        $response = $this->get('/api/check', ['Origin' => 'https://evil.example']);

        $this->assertNotSame(
            'https://evil.example',
            $response->headers->get('Access-Control-Allow-Origin'),
        );
    }

    /**
     * A request from a configured origin is reflected back, so legitimate
     * browser clients keep working.
     */
    #[Test]
    public function allowed_origin_is_reflected(): void
    {
        $response = $this->get('/api/check', ['Origin' => 'https://reacti.io']);

        $this->assertSame(
            'https://reacti.io',
            $response->headers->get('Access-Control-Allow-Origin'),
        );
    }
}
