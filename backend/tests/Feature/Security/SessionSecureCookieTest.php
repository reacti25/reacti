<?php

namespace Tests\Feature\Security;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins that session cookies are Secure (HTTPS-only) outside local dev
 * (backlog §1 / EP2).
 *
 * config/session.php previously read SESSION_SECURE_COOKIE with no default, so
 * an unset value left `secure` null and cookies were sent over HTTP. It now
 * defaults to true whenever APP_ENV is not `local`.
 */
class SessionSecureCookieTest extends TestCase
{
    #[Test]
    public function session_cookies_are_secure_outside_local_env(): void
    {
        // The test suite runs as APP_ENV=testing (not local), and
        // SESSION_SECURE_COOKIE is unset, so the new default applies.
        $this->assertNotSame('local', config('app.env'));
        $this->assertTrue(
            config('session.secure'),
            'session cookies must be Secure outside local dev',
        );
    }
}
