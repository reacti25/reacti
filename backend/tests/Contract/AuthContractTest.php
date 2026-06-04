<?php

namespace Tests\Contract;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;

/**
 * Contract tests for the auth/identity endpoints the iOS app depends on
 * for its session token and profile screen.
 *
 * Locks the response shape of login and profile so a backend change that
 * alters either (e.g. dropping `data.token` or renaming `total_friends`)
 * is caught before it can break the live app.
 */
class AuthContractTest extends ContractTestCase
{
    use RefreshDatabase;

    /** POST /api/login matches the login contract (the session-token payload). */
    #[Test]
    public function login_matches_contract(): void
    {
        User::factory()->create([
            'email' => 'contract@reacti.test',
            'password' => Hash::make('contract-password'),
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'contract@reacti.test',
            'password' => 'contract-password',
        ]);

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'login');
    }

    /** GET /api/profile matches the profile contract. */
    #[Test]
    public function profile_matches_contract(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'api')->getJson('/api/profile');

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'profile');
    }
}
