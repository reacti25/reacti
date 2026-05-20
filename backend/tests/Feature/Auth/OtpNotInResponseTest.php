<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The reset / registration OTP must never appear in an API response
 * body — it is delivered only by email. Returning it let anyone who
 * could call forgot-password / resend-otp for an address read that
 * account's OTP, defeating the entire OTP flow.
 *
 * The successful envelope is `{success, message, data, code}` — the
 * service's return array becomes `data`, so any `'otp' => ...` key in
 * a return array would surface as `data.otp`.
 */
class OtpNotInResponseTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function forgot_password_response_omits_the_otp(): void
    {
        Mail::fake();
        User::factory()->create([
            'email' => 'alice@example.com',
            'status' => 'active',
        ]);

        $resp = $this->postJson('/api/forgot-password', [
            'email' => 'alice@example.com',
        ]);

        $resp->assertOk();
        $resp->assertJsonMissingPath('data.otp');
    }

    #[Test]
    public function resend_otp_response_omits_the_otp(): void
    {
        Mail::fake();
        User::factory()->create([
            'email' => 'alice@example.com',
            'status' => 'active',
            'otp' => '1111',
            'otp_expires_at' => now()->subMinutes(2),
        ]);

        $resp = $this->postJson('/api/resend-otp', [
            'email' => 'alice@example.com',
        ]);

        $resp->assertOk();
        $resp->assertJsonMissingPath('data.otp');
    }

    #[Test]
    public function resend_register_otp_response_omits_the_otp(): void
    {
        Mail::fake();
        $email = 'pending@example.com';

        // Seed the in-progress registration cache that resendRegisterOtp
        // looks up. Without this it 404s ("no pending registration").
        Cache::put("register_data_{$email}", [
            'first_name' => 'Pending',
            'last_name' => 'User',
            'email' => $email,
            'phone' => null,
            'password' => 'already-hashed',
            'username' => 'pendinguser',
            'otp' => 1234,
            'otp_expires_at' => now()->addMinutes(5),
            'attempts' => 0,
        ], 300);

        $resp = $this->postJson('/api/resend-register-otp', [
            'email' => $email,
        ]);

        $resp->assertOk();
        $resp->assertJsonMissingPath('data.otp');
    }
}
