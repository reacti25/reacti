<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function a_user_can_log_in_with_valid_credentials(): void
    {
        $user = User::factory()->create([
            'email'    => 'alice@example.com',
            'password' => Hash::make('correct-horse'),
        ]);

        $response = $this->postJson('/api/login', [
            'email'    => 'alice@example.com',
            'password' => 'correct-horse',
        ]);

        $response->assertOk();
        $response->assertJsonStructure([
            'data' => ['access_token'],
        ]);
    }

    /** @test */
    public function login_rejects_wrong_password(): void
    {
        User::factory()->create([
            'email'    => 'alice@example.com',
            'password' => Hash::make('correct-horse'),
        ]);

        $response = $this->postJson('/api/login', [
            'email'    => 'alice@example.com',
            'password' => 'wrong',
        ]);

        $response->assertStatus(401);
    }
}
