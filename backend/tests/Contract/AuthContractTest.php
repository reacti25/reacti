<?php

namespace Tests\Contract;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
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

    /**
     * POST /api/register matches the register contract (the OTP-sent payload).
     *
     * Registration does not create the account — it emails a verification
     * OTP and returns the pending email/username — so the mailer is faked.
     */
    #[Test]
    public function register_matches_contract(): void
    {
        Mail::fake();

        $response = $this->postJson('/api/register', [
            'first_name' => 'Reg',
            // last_name is sent by the live app; the register service reads it
            // unguarded (a separate latent bug when omitted — out of scope here).
            'last_name' => 'Tester',
            'email' => 'newreg@reacti.test',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'register');
    }

    /** GET /api/user-profile/{id} matches the user-profile contract. */
    #[Test]
    public function user_profile_matches_contract(): void
    {
        $viewer = User::factory()->create();
        $target = User::factory()->create();

        $response = $this->actingAs($viewer, 'api')->getJson('/api/user-profile/'.$target->id);

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'user-profile');
    }
}
