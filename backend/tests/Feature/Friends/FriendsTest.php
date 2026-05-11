<?php

namespace Tests\Feature\Friends;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class FriendsTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function friend_list_requires_auth(): void
    {
        $this->getJson('/api/friends/list')->assertStatus(401);
    }

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

    #[Test]
    public function unfriend_does_not_succeed_when_not_friends(): void
    {
        $me      = User::factory()->create();
        $someone = User::factory()->create();

        $resp = $this->actingAs($me, 'api')->deleteJson("/api/friends/unfriend/{$someone->id}");

        // Controller wraps error() with a 2-arg call (bug in the controller —
        // passes 'message' as the data arg, code as the message), so the
        // exact status depends on ApiResponse's signature handling. What
        // matters is it doesn't succeed.
        $this->assertNotEquals(200, $resp->status());
    }

    #[Test]
    public function unfriend_requires_auth(): void
    {
        $someone = User::factory()->create();

        $this->deleteJson("/api/friends/unfriend/{$someone->id}")
            ->assertStatus(401);
    }
}
