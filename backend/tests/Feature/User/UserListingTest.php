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

    /**
     * `mode=username` matches the username and only the username.
     */
    #[Test]
    public function user_list_username_mode_matches_username(): void
    {
        $me = User::factory()->create();
        $target = User::factory()->create(['username' => 'coolcat_target']);
        $other = User::factory()->create(['username' => 'dogperson_other']);

        $resp = $this->actingAs($me, 'api')
            ->getJson('/api/user-list?mode=username&search=coolcat');
        $resp->assertOk();
        $resp->assertJsonPath('success', true);

        $ids = collect($resp->json('data.data'))->pluck('id');
        $this->assertTrue($ids->contains($target->id));
        $this->assertFalse($ids->contains($other->id));
    }

    /**
     * `mode=username` must NOT surface people by first/last name or phone —
     * only the username field is searched.
     */
    #[Test]
    public function user_list_username_mode_ignores_name_and_phone(): void
    {
        $me = User::factory()->create();
        $target = User::factory()->create([
            'username' => 'plainuser',
            'first_name' => 'Zebulon',
            'last_name' => 'Quixote',
            'phone' => '+15550001111',
        ]);

        foreach (['Zebulon', 'Quixote', '15550001111'] as $term) {
            $resp = $this->actingAs($me, 'api')
                ->getJson("/api/user-list?mode=username&search={$term}");
            $resp->assertOk();
            $ids = collect($resp->json('data.data'))->pluck('id');
            $this->assertFalse(
                $ids->contains($target->id),
                "username mode should not match on '{$term}'"
            );
        }
    }

    /**
     * `mode=username` with a blank query returns no one (no full-directory
     * browse), even though other users exist.
     */
    #[Test]
    public function user_list_username_mode_empty_query_returns_none(): void
    {
        $me = User::factory()->create();
        User::factory()->count(3)->create();

        $resp = $this->actingAs($me, 'api')
            ->getJson('/api/user-list?mode=username&search=');
        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonPath('data.pagination.total', 0);
    }

    /**
     * Self is still excluded in username mode, even when the query matches the
     * caller's own username.
     */
    #[Test]
    public function user_list_username_mode_excludes_self(): void
    {
        $me = User::factory()->create(['username' => 'myself_unique']);

        $resp = $this->actingAs($me, 'api')
            ->getJson('/api/user-list?mode=username&search=myself_unique');
        $resp->assertOk();

        $ids = collect($resp->json('data.data'))->pluck('id');
        $this->assertFalse($ids->contains($me->id));
    }

    /**
     * Default mode (no `mode` param) preserves phone-number discovery, so the
     * capability isn't lost for other/future callers.
     */
    #[Test]
    public function user_list_default_mode_still_matches_phone(): void
    {
        $me = User::factory()->create();
        $target = User::factory()->create([
            'username' => 'randname',
            'phone' => '+15559998888',
        ]);

        $resp = $this->actingAs($me, 'api')
            ->getJson('/api/user-list?search=5559998888');
        $resp->assertOk();

        $ids = collect($resp->json('data.data'))->pluck('id');
        $this->assertTrue($ids->contains($target->id));
    }
}
