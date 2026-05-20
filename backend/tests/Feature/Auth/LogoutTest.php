<?php

namespace Tests\Feature\Auth;

use App\Models\FirebaseTokens;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;
use Tymon\JWTAuth\Facades\JWTAuth;

/**
 * POST /api/logout — AuthenticationController::logout.
 *
 * logout() invalidates the caller's JWT, optionally drops a device's
 * Firebase push token, and broadcasts UserOnlineEvent(online=false).
 *
 * These tests authenticate with a *real* bearer token rather than
 * actingAs(): logout() resolves the token off the request via
 * auth('api')->logout(), so actingAs() alone (which sets only the user
 * resolver, no token) would make the controller throw and return 500.
 *
 * This file is a protective test added ahead of the CP1 Auth refactor —
 * logout had no coverage before.
 */
class LogoutTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Issue a real JWT for $user so logout() has a token to invalidate.
     *
     * @param  User  $user  The user to authenticate as.
     * @return string A signed JWT for the Authorization header.
     */
    private function tokenFor(User $user): string
    {
        return JWTAuth::fromUser($user);
    }

    /** An authenticated logout returns 200 with success:true. */
    #[Test]
    public function logout_succeeds_for_an_authenticated_user(): void
    {
        $user = User::factory()->create();

        $resp = $this->withHeader('Authorization', 'Bearer '.$this->tokenFor($user))
            ->postJson('/api/logout');

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
    }

    /**
     * When a device_id is supplied, that device's Firebase token row is
     * deleted so the server stops pushing to a signed-out client.
     */
    #[Test]
    public function logout_with_device_id_removes_that_devices_firebase_token(): void
    {
        $user = User::factory()->create();
        FirebaseTokens::create([
            'user_id' => $user->id,
            'device_id' => 'device-123',
            'token' => 'fcm-token-xyz',
        ]);

        $resp = $this->withHeader('Authorization', 'Bearer '.$this->tokenFor($user))
            ->postJson('/api/logout', ['device_id' => 'device-123']);

        $resp->assertOk();
        $this->assertDatabaseMissing('firebase_tokens', [
            'user_id' => $user->id,
            'device_id' => 'device-123',
        ]);
    }

    /**
     * A device_id belonging to another user is left untouched — logout
     * only removes the acting user's token for that device.
     */
    #[Test]
    public function logout_does_not_remove_another_users_firebase_token(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        FirebaseTokens::create([
            'user_id' => $other->id,
            'device_id' => 'device-123',
            'token' => 'other-fcm-token',
        ]);

        $this->withHeader('Authorization', 'Bearer '.$this->tokenFor($user))
            ->postJson('/api/logout', ['device_id' => 'device-123'])
            ->assertOk();

        // The other user's token for the same device id survives.
        $this->assertDatabaseHas('firebase_tokens', [
            'user_id' => $other->id,
            'device_id' => 'device-123',
        ]);
    }

    /** Unauthenticated logout is blocked by the auth:api middleware → 401. */
    #[Test]
    public function logout_requires_authentication(): void
    {
        $this->postJson('/api/logout')->assertStatus(401);
    }
}
