<?php

namespace Tests\Feature\Firebase;

use App\Models\FirebaseTokens;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class FirebaseTokenTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function store_persists_a_token_row(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/add', [
            'token'     => 'abc-token-123',
            'device_id' => 'device-xyz',
        ]);

        $resp->assertOk();
        $this->assertDatabaseHas('firebase_tokens', [
            'user_id'   => $user->id,
            'token'     => 'abc-token-123',
            'device_id' => 'device-xyz',
            'status'    => 'active',
        ]);
    }

    #[Test]
    public function store_validates_required_fields(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/add', []);
        $resp->assertStatus(400);
    }

    #[Test]
    public function store_requires_auth(): void
    {
        $this->postJson('/api/firebase/token/add', [
            'token'     => 'x',
            'device_id' => 'x',
        ])->assertStatus(401);
    }

    #[Test]
    public function get_token_returns_the_user_token_for_device(): void
    {
        $user  = User::factory()->create();
        $token = FirebaseTokens::create([
            'user_id'   => $user->id,
            'token'     => 'tok',
            'device_id' => 'dev1',
            'status'    => 'active',
        ]);

        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/get', [
            'device_id' => 'dev1',
        ]);
        $resp->assertOk();
        $resp->assertJsonPath('data.id', $token->id);
    }

    #[Test]
    public function get_token_returns_404_when_missing(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/get', [
            'device_id' => 'never-registered',
        ]);
        $resp->assertStatus(404);
    }

    #[Test]
    public function get_token_validates_device_id(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/get', []);
        $resp->assertStatus(400);
    }

    #[Test]
    public function get_token_requires_auth(): void
    {
        $this->postJson('/api/firebase/token/get', ['device_id' => 'x'])
            ->assertStatus(401);
    }

    #[Test]
    public function delete_token_removes_the_row(): void
    {
        $user  = User::factory()->create();
        $token = FirebaseTokens::create([
            'user_id'   => $user->id,
            'token'     => 'tok',
            'device_id' => 'dev1',
            'status'    => 'active',
        ]);

        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/delete', [
            'device_id' => 'dev1',
        ]);
        $resp->assertOk();
        $this->assertDatabaseMissing('firebase_tokens', ['id' => $token->id]);
    }

    #[Test]
    public function delete_token_validates_device_id(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->postJson('/api/firebase/token/delete', []);
        $resp->assertStatus(400);
    }

    #[Test]
    public function delete_token_requires_auth(): void
    {
        $this->postJson('/api/firebase/token/delete', ['device_id' => 'x'])
            ->assertStatus(401);
    }
}
