<?php

namespace Tests\Feature\Firebase;

use App\Models\FirebaseTokens;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Firebase Cloud Messaging tokens are stored one-per-device-per-user
 * in `firebase_tokens`. The mobile client posts the device token on
 * login + after every refresh; logout deletes it.
 *
 * Endpoints under /api/firebase/:
 *
 *   POST token/add     — upsert by (user_id, device_id)
 *   POST token/get     — read your own token for a device
 *   POST token/delete  — remove your token for a device
 *
 * The actual push-notification send (Helper::sendNotifyMobile) is
 * NOT covered here — it requires Firebase credentials and a real
 * service-account JSON, which CI doesn't have. Token storage is what
 * we lock.
 */
class FirebaseTokenTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Happy path for /firebase/token/add. Posting valid token + device_id
     * creates a row in firebase_tokens with status='active'. We assert
     * all four columns so a regression that drops status/device_id is
     * caught.
     */
    #[Test]
    public function store_persists_a_token_row(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/add', [
            'token' => 'abc-token-123',
            'device_id' => 'device-xyz',
        ]);

        $resp->assertOk();
        $this->assertDatabaseHas('firebase_tokens', [
            'user_id' => $user->id,
            'token' => 'abc-token-123',
            'device_id' => 'device-xyz',
            'status' => 'active',
        ]);
    }

    /** Missing token + device_id → 400 (the controller uses 400, not 422). */
    #[Test]
    public function store_validates_required_fields(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/add', []);
        $resp->assertStatus(400);
    }

    /** No auth → 401. Anonymous clients can't register a token. */
    #[Test]
    public function store_requires_auth(): void
    {
        $this->postJson('/api/firebase/token/add', [
            'token' => 'x',
            'device_id' => 'x',
        ])->assertStatus(401);
    }

    /**
     * Seed a token then read it back. The lookup is scoped by both
     * user_id AND device_id, so the same device key for a different
     * user wouldn't match.
     */
    #[Test]
    public function get_token_returns_the_user_token_for_device(): void
    {
        $user = User::factory()->create();
        $token = FirebaseTokens::create([
            'user_id' => $user->id,
            'token' => 'tok',
            'device_id' => 'dev1',
            'status' => 'active',
        ]);

        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/get', [
            'device_id' => 'dev1',
        ]);
        $resp->assertOk();
        $resp->assertJsonPath('data.id', $token->id);
    }

    /** Unknown device_id → 404. */
    #[Test]
    public function get_token_returns_404_when_missing(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/get', [
            'device_id' => 'never-registered',
        ]);
        $resp->assertStatus(404);
    }

    /** Missing device_id → 400 (validator rule). */
    #[Test]
    public function get_token_validates_device_id(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/get', []);
        $resp->assertStatus(400);
    }

    /** No auth → 401. */
    #[Test]
    public function get_token_requires_auth(): void
    {
        $this->postJson('/api/firebase/token/get', ['device_id' => 'x'])
            ->assertStatus(401);
    }

    /**
     * Seed a token then call delete; row should be gone afterwards.
     * Important because logout is supposed to drop the device token
     * so the server stops trying to push notifications to a now-signed-out
     * client.
     */
    #[Test]
    public function delete_token_removes_the_row(): void
    {
        $user = User::factory()->create();
        $token = FirebaseTokens::create([
            'user_id' => $user->id,
            'token' => 'tok',
            'device_id' => 'dev1',
            'status' => 'active',
        ]);

        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/delete', [
            'device_id' => 'dev1',
        ]);
        $resp->assertOk();
        $this->assertDatabaseMissing('firebase_tokens', ['id' => $token->id]);
    }

    /** Missing device_id → 400. */
    #[Test]
    public function delete_token_validates_device_id(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/delete', []);
        $resp->assertStatus(400);
    }

    /** No auth → 401. */
    #[Test]
    public function delete_token_requires_auth(): void
    {
        $this->postJson('/api/firebase/token/delete', ['device_id' => 'x'])
            ->assertStatus(401);
    }

    /**
     * GET /firebase/test is a diagnostic endpoint. With no tokens
     * registered for the user it makes no FCM push call and just echoes
     * back an empty token set with status:true.
     *
     * Protective test added ahead of the CP3 refactor — the `test`
     * action had no coverage.
     */
    #[Test]
    public function test_endpoint_returns_the_users_tokens(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->getJson('/api/firebase/test');

        $resp->assertOk();
        $resp->assertJsonPath('status', true);
        $resp->assertJsonPath('data', []);
    }

    /** No auth → 401. */
    #[Test]
    public function test_endpoint_requires_auth(): void
    {
        $this->getJson('/api/firebase/test')->assertStatus(401);
    }
}
