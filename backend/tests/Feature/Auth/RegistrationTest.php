<?php

namespace Tests\Feature\Auth;

use App\Mail\EmailVerifyMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The registration flow is two API calls:
 *
 *   1. POST /api/register          — caches pending user data + OTP, mails the OTP.
 *      No `users` row is created yet.
 *   2. POST /api/email-verify      — consumes the cached data + OTP, creates the user.
 *
 * Resend lives at POST /api/resend-register-otp.
 *
 * These tests pin all three endpoints across happy, validation, and
 * permission paths. The CACHE_STORE=array and MAIL_MAILER=array env
 * (set in phpunit.xml) make Cache::put / Mail::to safe in-process.
 */
class RegistrationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Happy path for the first leg. The endpoint should:
     *   - return 200 + success:true
     *   - cache the pending user data + OTP under the email key
     *   - NOT create a row in `users` (that only happens on verify)
     *   - send an EmailVerifyMail
     *
     * Mail::fake() is set up before the call so the mail send is
     * captured in memory rather than going out the SMTP driver.
     */
    #[Test]
    public function register_caches_pending_user_and_sends_otp_email(): void
    {
        Mail::fake();

        $resp = $this->postJson('/api/register', [
            'first_name' => 'Alice',
            'last_name' => 'Anders',
            'email' => 'alice@example.com',
            'phone' => '+12025550100',
            'password' => 'correct-horse',
            'password_confirmation' => 'correct-horse',
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonPath('data.email', 'alice@example.com');

        // No DB row yet — verifyEmail is what creates it.
        $this->assertDatabaseMissing('users', ['email' => 'alice@example.com']);

        // OTP and pending data are cached for the verify step.
        $this->assertNotNull(Cache::get('register_otp_alice@example.com'));
        $this->assertNotNull(Cache::get('register_data_alice@example.com'));

        Mail::assertSent(EmailVerifyMail::class);
    }

    /** first_name is required by UserRegisterRequest; missing it → 422. */
    #[Test]
    public function register_rejects_missing_first_name(): void
    {
        $resp = $this->postJson('/api/register', [
            'email' => 'b@example.com',
            'password' => 'correct-horse',
            'password_confirmation' => 'correct-horse',
        ]);

        $resp->assertStatus(422);
    }

    /** `confirmed` rule fires when password ≠ password_confirmation → 422. */
    #[Test]
    public function register_rejects_password_confirm_mismatch(): void
    {
        $resp = $this->postJson('/api/register', [
            'first_name' => 'Alice',
            'email' => 'a@example.com',
            'password' => 'correct-horse',
            'password_confirmation' => 'wrong-horse',
        ]);

        $resp->assertStatus(422);
    }

    /** Minimum 8 chars per the validator → 422. */
    #[Test]
    public function register_rejects_short_password(): void
    {
        $resp = $this->postJson('/api/register', [
            'first_name' => 'Alice',
            'email' => 'a@example.com',
            'password' => 'short',
            'password_confirmation' => 'short',
        ]);

        $resp->assertStatus(422);
    }

    /**
     * `unique:users,email` short-circuits before we even touch the
     * cache, so a seeded duplicate user blocks the registration. → 422.
     */
    #[Test]
    public function register_rejects_duplicate_email(): void
    {
        User::factory()->create(['email' => 'taken@example.com']);

        $resp = $this->postJson('/api/register', [
            'first_name' => 'Alice',
            'email' => 'taken@example.com',
            'password' => 'correct-horse',
            'password_confirmation' => 'correct-horse',
        ]);

        $resp->assertStatus(422);
    }

    /**
     * Happy path for the second leg. We pre-seed the cache the way
     * /register would have, then POST the matching OTP. The controller
     * should:
     *   - hash-promote the cached password (already hashed in cache)
     *     into a real `users` row
     *   - mark the user active + otp_verified_at=now
     *   - clear the three cache keys so the OTP can't be re-used
     */
    #[Test]
    public function verify_email_creates_user_when_otp_matches(): void
    {
        $email = 'alice@example.com';
        $otp = 1234;

        Cache::put("register_otp_{$email}", $otp, 300);
        Cache::put("register_data_{$email}", [
            'first_name' => 'Alice',
            'last_name' => 'Anders',
            'email' => $email,
            'phone' => '+12025550100',
            'username' => 'alice',
            'password' => bcrypt('correct-horse'),
            'otp' => $otp,
            'otp_expires_at' => now()->addMinutes(5),
            'attempts' => 0,
        ], 300);

        $resp = $this->postJson('/api/email-verify', [
            'email' => $email,
            'otp' => $otp,
        ]);

        $resp->assertOk();
        $this->assertDatabaseHas('users', [
            'email' => $email,
            'username' => 'alice',
            'status' => 'active',
        ]);
        // Cache is cleaned out after a successful verify.
        $this->assertNull(Cache::get("register_otp_{$email}"));
        $this->assertNull(Cache::get("register_data_{$email}"));
    }

    /**
     * If the OTP submitted doesn't match what was cached, the user
     * must NOT be created and the response must be 403. A regression
     * that created the user anyway would let an attacker register an
     * account just by knowing an email address (no OTP needed).
     */
    #[Test]
    public function verify_email_rejects_wrong_otp(): void
    {
        $email = 'alice@example.com';
        Cache::put("register_otp_{$email}", 1234, 300);
        Cache::put("register_data_{$email}", [
            'first_name' => 'Alice',
            'last_name' => 'Anders',
            'email' => $email,
            'phone' => '+12025550100',
            'username' => 'alice',
            'password' => bcrypt('correct-horse'),
            'otp' => 1234,
            'otp_expires_at' => now()->addMinutes(5),
            'attempts' => 0,
        ], 300);

        $resp = $this->postJson('/api/email-verify', [
            'email' => $email,
            'otp' => 9999,
        ]);

        $resp->assertStatus(403);
        $this->assertDatabaseMissing('users', ['email' => $email]);
    }

    /**
     * Calling /email-verify with no prior /register call (no cache
     * entry) returns 404. Important so an attacker can't blind-guess
     * OTPs for an email that never started a registration.
     */
    #[Test]
    public function verify_email_returns_404_when_no_pending_registration(): void
    {
        $resp = $this->postJson('/api/email-verify', [
            'email' => 'nobody@example.com',
            'otp' => 1234,
        ]);

        $resp->assertStatus(404);
    }

    /** OTP must be exactly 4 digits per the validator → 422. */
    #[Test]
    public function verify_email_validates_otp_shape(): void
    {
        $resp = $this->postJson('/api/email-verify', [
            'email' => 'a@example.com',
            'otp' => 'not-a-number',
        ]);

        $resp->assertStatus(422);
    }

    /**
     * Resend only works if there's a pending registration in cache.
     * Otherwise we'd send OTP emails to random addresses on request.
     */
    #[Test]
    public function resend_register_otp_returns_404_without_pending_registration(): void
    {
        $resp = $this->postJson('/api/resend-register-otp', [
            'email' => 'nobody@example.com',
        ]);

        $resp->assertStatus(404);
    }

    /**
     * With a pending registration in cache, resend should:
     *   - rotate the OTP (so the old one is invalidated)
     *   - mail the new one out
     * Otherwise a leaked-but-now-expired OTP could be reused.
     */
    #[Test]
    public function resend_register_otp_refreshes_otp_and_resends_mail(): void
    {
        Mail::fake();

        $email = 'alice@example.com';
        Cache::put("register_otp_{$email}", 1111, 300);
        Cache::put("register_data_{$email}", [
            'first_name' => 'Alice',
            'last_name' => 'Anders',
            'email' => $email,
            'phone' => '+12025550100',
            'username' => 'alice',
            'password' => bcrypt('correct-horse'),
            'otp' => 1111,
            'otp_expires_at' => now()->addMinutes(5),
            'attempts' => 0,
        ], 300);

        $resp = $this->postJson('/api/resend-register-otp', [
            'email' => $email,
        ]);

        $resp->assertOk();
        Mail::assertSent(EmailVerifyMail::class);
        // OTP rotated.
        $this->assertNotSame(1111, Cache::get("register_otp_{$email}"));
    }
}
