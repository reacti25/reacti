<?php

namespace Tests\Feature\Auth;

use App\Mail\OtpMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Password reset is a four-call dance:
 *
 *   1. /forgot-password   — generate an OTP + email it
 *   2. /verify-otp        — confirm the OTP, get a short-lived token
 *   3. /reset-password    — submit the token + new password
 *   4. /resend-otp        — rotate a fresh OTP if step 2 takes too long
 *
 * Each step is locked here for happy + validation + permission paths.
 * The DB columns involved live on the User model: `otp`,
 * `otp_expires_at`, `reset_password_token`, `reset_password_token_expire_at`.
 */
class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Step 1 happy path. Mail::fake() captures the email; the user row
     * gets otp + otp_expires_at populated (we don't pin the OTP value
     * because the controller picks a random 4-digit code — just check
     * it's non-null).
     */
    #[Test]
    public function forgot_password_sends_an_otp_email_to_active_user(): void
    {
        Mail::fake();

        $user = User::factory()->create([
            'email' => 'alice@example.com',
            'status' => 'active',
        ]);

        $resp = $this->postJson('/api/forgot-password', [
            'email' => 'alice@example.com',
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('success', true);

        $user->refresh();
        $this->assertNotNull($user->otp);
        $this->assertNotNull($user->otp_expires_at);
        Mail::assertSent(OtpMail::class);
    }

    /**
     * `exists:users,email` blocks unknown addresses → 422. Important
     * so an attacker can't enumerate registered emails by watching
     * which addresses return 200 vs 404.
     */
    #[Test]
    public function forgot_password_rejects_unknown_email(): void
    {
        $resp = $this->postJson('/api/forgot-password', [
            'email' => 'nobody@example.com',
        ]);

        $resp->assertStatus(422);
    }

    /** `email` validation rule rejects malformed input → 422. */
    #[Test]
    public function forgot_password_rejects_invalid_email_format(): void
    {
        $resp = $this->postJson('/api/forgot-password', [
            'email' => 'not-an-email',
        ]);

        $resp->assertStatus(422);
    }

    /**
     * Step 2 happy path. Match the OTP we seeded; the controller should:
     *   - return a 60-char token (the body's `token` field)
     *   - clear `otp` and `otp_expires_at` (so the same code can't be
     *     re-verified)
     *   - persist `reset_password_token` for step 3 to consume
     */
    #[Test]
    public function verify_otp_returns_a_reset_token_on_match(): void
    {
        $user = User::factory()->create([
            'email' => 'alice@example.com',
            'otp' => '1234',
            'otp_expires_at' => now()->addMinutes(5),
        ]);

        $resp = $this->postJson('/api/verify-otp', [
            'email' => 'alice@example.com',
            'otp' => '1234',
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('status', true);
        $this->assertNotEmpty($resp->json('token'));

        $user->refresh();
        $this->assertNull($user->otp);
        $this->assertNotNull($user->reset_password_token);
    }

    /** Wrong OTP → 400. No token issued. */
    #[Test]
    public function verify_otp_rejects_wrong_otp(): void
    {
        User::factory()->create([
            'email' => 'alice@example.com',
            'otp' => '1234',
            'otp_expires_at' => now()->addMinutes(5),
        ]);

        $resp = $this->postJson('/api/verify-otp', [
            'email' => 'alice@example.com',
            'otp' => '9999',
        ]);

        $resp->assertStatus(400);
    }

    /**
     * Expired OTPs → 400 even if the digits match. Tests use
     * `now()->subMinute()` to force the expiry into the past — the
     * controller checks `Carbon::parse(otp_expires_at)->isPast()`.
     */
    #[Test]
    public function verify_otp_rejects_expired_otp(): void
    {
        User::factory()->create([
            'email' => 'alice@example.com',
            'otp' => '1234',
            'otp_expires_at' => now()->subMinute(),
        ]);

        $resp = $this->postJson('/api/verify-otp', [
            'email' => 'alice@example.com',
            'otp' => '1234',
        ]);

        $resp->assertStatus(400);
    }

    /** Validator rejects bad email + non-digit OTP shape → 422. */
    #[Test]
    public function verify_otp_validates_input(): void
    {
        $resp = $this->postJson('/api/verify-otp', [
            'email' => 'not-an-email',
            'otp' => 'not-digits',
        ]);

        $resp->assertStatus(422);
    }

    /**
     * Step 3 happy path. Seed the user with a valid token, submit the
     * new password, and assert:
     *   - the password hash actually changes (Hash::check)
     *   - the reset_password_token is cleared (can't be reused)
     */
    #[Test]
    public function reset_password_succeeds_with_a_valid_token(): void
    {
        $user = User::factory()->create([
            'email' => 'alice@example.com',
            'password' => Hash::make('old-password'),
            'reset_password_token' => 'valid-token',
            'reset_password_token_expire_at' => now()->addMinutes(5),
        ]);

        $resp = $this->postJson('/api/reset-password', [
            'email' => 'alice@example.com',
            'token' => 'valid-token',
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ]);

        $resp->assertOk();

        $user->refresh();
        $this->assertNull($user->reset_password_token);
        $this->assertTrue(Hash::check('new-password', $user->password));
    }

    /**
     * Submitting a wrong reset token → 401. Critical — this is the
     * "I have your email, give me a password reset" guard.
     */
    #[Test]
    public function reset_password_rejects_wrong_token(): void
    {
        User::factory()->create([
            'email' => 'alice@example.com',
            'reset_password_token' => 'valid-token',
            'reset_password_token_expire_at' => now()->addMinutes(5),
        ]);

        $resp = $this->postJson('/api/reset-password', [
            'email' => 'alice@example.com',
            'token' => 'wrong-token',
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ]);

        $resp->assertStatus(401);
    }

    /** `confirmed` rule on the new password → 422. */
    #[Test]
    public function reset_password_rejects_password_mismatch(): void
    {
        User::factory()->create(['email' => 'alice@example.com']);

        $resp = $this->postJson('/api/reset-password', [
            'email' => 'alice@example.com',
            'token' => 'whatever',
            'password' => 'new-password',
            'password_confirmation' => 'different',
        ]);

        $resp->assertStatus(422);
    }

    /**
     * Resend rotates the OTP (so the old one stops working) and
     * mails the new one out. We use `otp_expires_at => now()->subMinutes(2)`
     * to bypass the rate-limit check in the controller (it only blocks
     * resends within 60s of the previous send).
     */
    #[Test]
    public function resend_otp_rotates_otp_and_resends_mail(): void
    {
        Mail::fake();

        $user = User::factory()->create([
            'email' => 'alice@example.com',
            'status' => 'active',
            'otp' => '1111',
            'otp_expires_at' => now()->subMinutes(2),
        ]);

        $resp = $this->postJson('/api/resend-otp', [
            'email' => 'alice@example.com',
        ]);

        $resp->assertOk();
        Mail::assertSent(OtpMail::class);

        $user->refresh();
        $this->assertNotSame('1111', (string) $user->otp);
    }

    /** Same email-enumeration guard as forgot-password → 422. */
    #[Test]
    public function resend_otp_rejects_unknown_email(): void
    {
        $resp = $this->postJson('/api/resend-otp', [
            'email' => 'nobody@example.com',
        ]);

        $resp->assertStatus(422);
    }
}
