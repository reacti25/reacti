<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * POST /api/login — credential authentication.
 *
 * Covers the happy path (valid email + password for an active,
 * OTP-verified account returns an API token) and the rejection path
 * (a wrong password is refused with 401). These tests pin the login
 * contract the Flutter client depends on for its session token.
 */
class LoginTest extends TestCase
{
    use RefreshDatabase;

    /** Valid credentials for an active, OTP-verified user → 200 with a non-empty `data.token`. */
    #[Test]
    public function a_user_can_log_in_with_valid_credentials(): void
    {
        $user = User::factory()->create([
            'email'           => 'alice@example.com',
            'password'        => Hash::make('correct-horse'),
            'otp_verified_at' => now(),
            'status'          => 'active',
        ]);

        $response = $this->postJson('/api/login', [
            'email'    => 'alice@example.com',
            'password' => 'correct-horse',
        ]);

        $response->assertOk();
        $response->assertJsonPath('success', true);
        $this->assertNotEmpty($response->json('data.token'));
    }

    /** Correct email but wrong password → 401 with the `Invalid password.` message. */
    #[Test]
    public function login_rejects_wrong_password(): void
    {
        User::factory()->create([
            'email'           => 'alice@example.com',
            'password'        => Hash::make('correct-horse'),
            'otp_verified_at' => now(),
            'status'          => 'active',
        ]);

        $response = $this->postJson('/api/login', [
            'email'    => 'alice@example.com',
            'password' => 'wrong-password-but-long-enough',
        ]);

        $response->assertStatus(401);
        $response->assertJsonPath('message', 'Invalid password.');
    }

    /**
     * An account that has not verified its email (no `otp_verified_at`)
     * is refused with 401 even when the password is correct.
     */
    #[Test]
    public function login_rejects_an_unverified_email(): void
    {
        User::factory()->create([
            'email'           => 'alice@example.com',
            'password'        => Hash::make('correct-horse'),
            'otp_verified_at' => null,
            'status'          => 'active',
        ]);

        $response = $this->postJson('/api/login', [
            'email'    => 'alice@example.com',
            'password' => 'correct-horse',
        ]);

        $response->assertStatus(401);
        $response->assertJsonPath('message', 'Please verify your email before logging in.');
    }

    /**
     * An email with no account is rejected at validation (422) by
     * ApiLoginRequest's `exists:users,email` rule — the request never
     * reaches the controller's own "Invalid email." 401 branch.
     */
    #[Test]
    public function login_rejects_an_unknown_email(): void
    {
        $response = $this->postJson('/api/login', [
            'email'    => 'nobody@example.com',
            'password' => 'correct-horse',
        ]);

        $response->assertStatus(422);
    }
}
