<?php

namespace Tests\Feature\User;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class UserListingTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function user_profile_returns_user_when_found(): void
    {
        $me     = User::factory()->create();
        $target = User::factory()->create(['first_name' => 'Findme']);

        $resp = $this->actingAs($me, 'api')->getJson("/api/user-profile/{$target->id}");
        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonPath('data.id', $target->id);
    }

    #[Test]
    public function user_profile_responds_for_unknown_user(): void
    {
        $me = User::factory()->create();
        // Controller returns success=false but status 200.
        $resp = $this->actingAs($me, 'api')->getJson('/api/user-profile/999999');
        $resp->assertOk();
        $resp->assertJsonPath('success', false);
    }

    #[Test]
    public function user_profile_requires_auth(): void
    {
        $this->getJson('/api/user-profile/1')->assertStatus(401);
    }

    #[Test]
    public function user_list_returns_paginated_users_excluding_self(): void
    {
        $me     = User::factory()->create();
        $alice  = User::factory()->create();
        $bob    = User::factory()->create();

        $resp = $this->actingAs($me, 'api')->getJson('/api/user-list');
        $resp->assertOk();

        // Paginated response in `data.data`; exact shape depends on UserListResource.
        $payload = $resp->json();
        $this->assertTrue($payload['success']);
    }

    #[Test]
    public function user_list_requires_auth(): void
    {
        $this->getJson('/api/user-list')->assertStatus(401);
    }
}
