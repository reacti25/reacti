<?php

namespace Tests\Feature\Friends;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Endpoints on FriendsController:
 *
 *   GET    /friends/list             — the auth user's friends
 *   GET    /friends/users/{user}/    — someone else's friend list
 *   DELETE /friends/unfriend/{id}    — remove a friendship
 *
 * The friendship is stored asymmetrically (one row in `friends` per
 * direction is possible, depending on which side initiated). The
 * unfriend tests exercise both insertion orders — the controller
 * must find the row whether we're stored as user_id or friend_id.
 */
class FriendsTest extends TestCase
{
    use RefreshDatabase;

    /** No auth → 401. */
    #[Test]
    public function friend_list_requires_auth(): void
    {
        $this->getJson('/api/friends/list')->assertStatus(401);
    }

    /**
     * Seeds three friendships:
     *   - me ↔ alice  stored as (user_id=me,  friend_id=alice)
     *   - me ↔ bob    stored as (user_id=bob, friend_id=me)
     *   - carol ↔ stranger (no `me` involvement)
     *
     * Expectation: the list returns alice + bob (both directions
     * picked up) and excludes carol/stranger/me. A regression that
     * only reads one direction would silently lose half the friends.
     */
    #[Test]
    public function friend_list_returns_both_directions_of_the_friendship_table(): void
    {
        $me     = User::factory()->create();
        $alice  = User::factory()->create();
        $bob    = User::factory()->create();
        $carol  = User::factory()->create();
        $stranger = User::factory()->create();

        // Friendship where I'm user_id
        DB::table('friends')->insert([
            'user_id'           => $me->id,
            'friend_id'         => $alice->id,
            'became_friends_at' => now(),
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);
        // Friendship where I'm friend_id
        DB::table('friends')->insert([
            'user_id'           => $bob->id,
            'friend_id'         => $me->id,
            'became_friends_at' => now(),
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);
        // Friendship not involving me
        DB::table('friends')->insert([
            'user_id'           => $carol->id,
            'friend_id'         => $stranger->id,
            'became_friends_at' => now(),
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);

        $resp = $this->actingAs($me, 'api')->getJson('/api/friends/list');
        $resp->assertOk();

        $ids = collect($resp->json('data'))->pluck('id')->all();
        $this->assertContains($alice->id, $ids);
        $this->assertContains($bob->id, $ids);
        $this->assertNotContains($carol->id, $ids);
        $this->assertNotContains($stranger->id, $ids);
        $this->assertNotContains($me->id, $ids);
    }

    /**
     * Friendship stored with me as user_id. Unfriend removes the row.
     */
    #[Test]
    public function unfriend_deletes_the_friendship_row(): void
    {
        $me     = User::factory()->create();
        $friend = User::factory()->create();

        DB::table('friends')->insert([
            'user_id'           => $me->id,
            'friend_id'         => $friend->id,
            'became_friends_at' => now(),
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);

        $resp = $this->actingAs($me, 'api')->deleteJson("/api/friends/unfriend/{$friend->id}");
        $resp->assertOk();

        $this->assertDatabaseMissing('friends', [
            'user_id'   => $me->id,
            'friend_id' => $friend->id,
        ]);
    }

    /**
     * Same as above but stored with the OTHER side as user_id. The
     * controller's lookup query must check both columns; if it only
     * checks one, this test catches it.
     */
    #[Test]
    public function unfriend_works_when_the_friendship_was_stored_with_other_side_as_user_id(): void
    {
        $me     = User::factory()->create();
        $friend = User::factory()->create();

        // Note: friendship stored with friend as user_id, me as friend_id.
        DB::table('friends')->insert([
            'user_id'           => $friend->id,
            'friend_id'         => $me->id,
            'became_friends_at' => now(),
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);

        $resp = $this->actingAs($me, 'api')->deleteJson("/api/friends/unfriend/{$friend->id}");
        $resp->assertOk();

        $this->assertDatabaseMissing('friends', [
            'user_id'   => $friend->id,
            'friend_id' => $me->id,
        ]);
    }

    /**
     * Trying to unfriend someone who isn't a friend should fail. The
     * status code is unreliable because of the controller bug noted
     * in the class docstring; we only assert "not 200".
     */
    #[Test]
    public function unfriend_returns_400_when_not_friends(): void
    {
        $me      = User::factory()->create();
        $someone = User::factory()->create();

        $resp = $this->actingAs($me, 'api')->deleteJson("/api/friends/unfriend/{$someone->id}");

        $resp->assertStatus(400)
            ->assertJsonPath('message', 'You are not friends with this user.');
    }

    /** No auth → 401. */
    #[Test]
    public function unfriend_requires_auth(): void
    {
        $someone = User::factory()->create();

        $this->deleteJson("/api/friends/unfriend/{$someone->id}")
            ->assertStatus(401);
    }

    #[Test]
    public function user_friend_list_returns_the_other_users_friends(): void
    {
        $me      = User::factory()->create();
        $profile = User::factory()->create();
        $friendA = User::factory()->create();
        $friendB = User::factory()->create();

        // profile <-> friendA  (profile = user_id)
        DB::table('friends')->insert([
            'user_id'           => $profile->id,
            'friend_id'         => $friendA->id,
            'became_friends_at' => now(),
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);
        // profile <-> friendB  (profile = friend_id) — both directions are accepted
        DB::table('friends')->insert([
            'user_id'           => $friendB->id,
            'friend_id'         => $profile->id,
            'became_friends_at' => now(),
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);

        $resp = $this->actingAs($me, 'api')->getJson("/api/friends/users/{$profile->id}/");
        $resp->assertOk();

        $ids = collect($resp->json('data'))->pluck('id')->all();
        $this->assertContains($friendA->id, $ids);
        $this->assertContains($friendB->id, $ids);
    }

    /**
     * If the profile owner has blocked me (row in `user_blocks` with
     * profile=user_id, me=block_user_id) the endpoint must refuse with
     * 403. This was previously broken because the controller queried a
     * non-existent `blocked_users` table — the SQL threw a 500 long
     * before the 403 branch could fire.
     */
    #[Test]
    public function user_friend_list_returns_403_when_profile_owner_blocked_me(): void
    {
        $me      = User::factory()->create();
        $profile = User::factory()->create();

        DB::table('user_blocks')->insert([
            'user_id'        => $profile->id, // blocker
            'block_user_id'  => $me->id,      // blocked
            'created_at'     => now(),
            'updated_at'     => now(),
        ]);

        $resp = $this->actingAs($me, 'api')->getJson("/api/friends/users/{$profile->id}/");

        $resp->assertStatus(403)
            ->assertJsonPath('message', 'You cannot view this user\'s friends.');
    }

    #[Test]
    public function user_friend_list_requires_auth(): void
    {
        $profile = User::factory()->create();

        $this->getJson("/api/friends/users/{$profile->id}/")
            ->assertStatus(401);
    }
}
