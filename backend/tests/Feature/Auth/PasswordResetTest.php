<?php

namespace Tests\Feature\Auth;

use App\Mail\OtpMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function forgot_password_sends_an_otp_email_to_active_user(): void
    {
        Mail::fake();

        $user = User::factory()->create([
            'email'  => 'alice@example.com',
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

    #[Test]
    public function forgot_password_rejects_unknown_email(): void
    {
        $resp = $this->postJson('/api/forgot-password', [
            'email' => 'nobody@example.com',
        ]);

        $resp->assertStatus(422);
    }

    #[Test]
    public function forgot_password_rejects_invalid_email_format(): void
    {
        $resp = $this->postJson('/api/forgot-password', [
            'email' => 'not-an-email',
        ]);

        $resp->assertStatus(422);
    }

    #[Test]
    public function verify_otp_returns_a_reset_token_on_match(): void
    {
        $user = User::factory()->create([
            'email'          => 'alice@example.com',
            'otp'            => '1234',
            'otp_expires_at' => now()->addMinutes(5),
        ]);

        $resp = $this->postJson('/api/verify-otp', [
            'email' => 'alice@example.com',
            'otp'   => '1234',
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('status', true);
        $this->assertNotEmpty($resp->json('token'));

        $user->refresh();
        $this->assertNull($user->otp);
        $this->assertNotNull($user->reset_password_token);
    }

    #[Test]
    public function verify_otp_rejects_wrong_otp(): void
    {
        User::factory()->create([
            'email'          => 'alice@example.com',
            'otp'            => '1234',
            'otp_expires_at' => now()->addMinutes(5),
        ]);

        $resp = $this->postJson('/api/verify-otp', [
            'email' => 'alice@example.com',
            'otp'   => '9999',
        ]);

        $resp->assertStatus(400);
    }

    #[Test]
    public function verify_otp_rejects_expired_otp(): void
    {
        User::factory()->create([
            'email'          => 'alice@example.com',
            'otp'            => '1234',
            'otp_expires_at' => now()->subMinute(),
        ]);

        $resp = $this->postJson('/api/verify-otp', [
            'email' => 'alice@example.com',
            'otp'   => '1234',
        ]);

        $resp->assertStatus(400);
    }

    #[Test]
    public function verify_otp_validates_input(): void
    {
        $resp = $this->postJson('/api/verify-otp', [
            'email' => 'not-an-email',
            'otp'   => 'not-digits',
        ]);

        $resp->assertStatus(422);
    }

    #[Test]
    public function reset_password_succeeds_with_a_valid_token(): void
    {
        $user = User::factory()->create([
            'email'                          => 'alice@example.com',
            'password'                       => Hash::make('old-password'),
            'reset_password_token'           => 'valid-token',
            'reset_password_token_expire_at' => now()->addMinutes(5),
        ]);

        $resp = $this->postJson('/api/reset-password', [
            'email'                 => 'alice@example.com',
            'token'                 => 'valid-token',
            'password'              => 'new-password',
            'password_confirmation' => 'new-password',
        ]);

        $resp->assertOk();

        $user->refresh();
        $this->assertNull($user->reset_password_token);
        $this->assertTrue(Hash::check('new-password', $user->password));
    }

    #[Test]
    public function reset_password_rejects_wrong_token(): void
    {
        User::factory()->create([
            'email'                          => 'alice@example.com',
            'reset_password_token'           => 'valid-token',
            'reset_password_token_expire_at' => now()->addMinutes(5),
        ]);

        $resp = $this->postJson('/api/reset-password', [
            'email'                 => 'alice@example.com',
            'token'                 => 'wrong-token',
            'password'              => 'new-password',
            'password_confirmation' => 'new-password',
        ]);

        $resp->assertStatus(401);
    }

    #[Test]
    public function reset_password_rejects_password_mismatch(): void
    {
        User::factory()->create(['email' => 'alice@example.com']);

        $resp = $this->postJson('/api/reset-password', [
            'email'                 => 'alice@example.com',
            'token'                 => 'whatever',
            'password'              => 'new-password',
            'password_confirmation' => 'different',
        ]);

        $resp->assertStatus(422);
    }

    #[Test]
    public function resend_otp_rotates_otp_and_resends_mail(): void
    {
        Mail::fake();

        $user = User::factory()->create([
            'email'          => 'alice@example.com',
            'status'         => 'active',
            'otp'            => '1111',
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

    #[Test]
    public function resend_otp_rejects_unknown_email(): void
    {
        $resp = $this->postJson('/api/resend-otp', [
            'email' => 'nobody@example.com',
        ]);

        $resp->assertStatus(422);
    }
}
