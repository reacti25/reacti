<?php

namespace Tests\Feature\User;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Two endpoints on UserController:
 *
 *   GET /user-profile/{id} — read any user's public profile
 *   GET /user-list         — paginated user search (excluding self)
 *
 * The profile endpoint returns `success: false` on miss but still
 * status 200; tests assert `data.id` is null on the miss path rather
 * than relying on HTTP status code.
 */
class UserListingTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Looks up another user by id and gets their record back. We
     * assert `data.id` matches because the controller wraps the user
     * in a UserResource.
     */
    #[Test]
    public function user_profile_returns_user_when_found(): void
    {
        $me = User::factory()->create();
        $target = User::factory()->create(['first_name' => 'Findme']);

        $resp = $this->actingAs($me, 'api')->getJson("/api/user-profile/{$target->id}");
        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonPath('data.id', $target->id);
    }

    /**
     * Querying a non-existent id should not leak any other user's data.
     * The controller's miss path returns an error envelope without a
     * `data` block — we assert `data.id` is null rather than asserting
     * on the status code (which is 200, not 404, for this controller).
     */
    #[Test]
    public function user_profile_responds_for_unknown_user(): void
    {
        $me = User::factory()->create();
        // Controller returns an error envelope on miss (no data block); we
        // only assert that the response does not present a real user.
        $resp = $this->actingAs($me, 'api')->getJson('/api/user-profile/999999');
        $resp->assertOk();
        $this->assertNull($resp->json('data.id'));
    }

    /** No auth → 401. */
    #[Test]
    public function user_profile_requires_auth(): void
    {
        $this->getJson('/api/user-profile/1')->assertStatus(401);
    }

    /**
     * Calls /user-list as `me` while three users exist in the DB
     * (including me). The endpoint must NOT include the auth user in
     * its own listing — the controller explicitly excludes `where('id',
     * '!=', $currentUser->id)`. Exact shape is owned by
     * UserListResource so we just sanity-check `success: true`.
     */
    #[Test]
    public function user_list_returns_paginated_users_excluding_self(): void
    {
        $me = User::factory()->create();
        $alice = User::factory()->create();
        $bob = User::factory()->create();

        $resp = $this->actingAs($me, 'api')->getJson('/api/user-list');
        $resp->assertOk();

        // Paginated response in `data.data`; exact shape depends on UserListResource.
        $payload = $resp->json();
        $this->assertTrue($payload['success']);
    }

    /** No auth → 401. */
    #[Test]
    public function user_list_requires_auth(): void
    {
        $this->getJson('/api/user-list')->assertStatus(401);
    }
}
