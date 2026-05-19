<?php

namespace Tests\Feature\Auth;

use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The guest auth/OTP routes carry `throttle:` middleware so the
 * 4-digit OTP (10,000 combinations) cannot be brute-forced. See the
 * guest route group in routes/api.php.
 */
class AuthRateLimitTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function otp_verification_is_rate_limited(): void
    {
        $payload = ['email' => 'attacker@example.com', 'otp' => '0000'];

        // throttle:6,1 — six requests/minute are allowed through to the
        // controller; the seventh is rejected by the rate limiter.
        for ($i = 0; $i < 6; $i++) {
            $response = $this->postJson('/api/verify-otp', $payload);
            $this->assertNotSame(429, $response->status());
        }

        $this->postJson('/api/verify-otp', $payload)->assertStatus(429);
    }

    #[Test]
    public function login_is_rate_limited(): void
    {
        $payload = ['email' => 'attacker@example.com', 'password' => 'wrong-password'];

        // throttle:12,1 — the thirteenth attempt within a minute is blocked.
        for ($i = 0; $i < 12; $i++) {
            $this->postJson('/api/login', $payload);
        }

        $this->postJson('/api/login', $payload)->assertStatus(429);
    }
}
