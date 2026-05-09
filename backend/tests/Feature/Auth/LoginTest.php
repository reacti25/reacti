<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

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
}
