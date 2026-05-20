<?php

namespace Tests\Feature\Moderation;

use App\Models\Friend;
use App\Models\FriendRequest;
use App\Models\User;
use App\Models\UserBlock;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Blocking is a toggle — the same POST creates the block on first call
 * and removes it on second. Like reporting, the first-time block also
 * tears down any existing friendship + pending requests with the
 * target so the chat list immediately stops showing them.
 *
 * Tests cover:
 *   - toggle on (creates row, tears down friendship)
 *   - toggle off (removes row)
 *   - 404 on unknown target
 *   - 400 on self
 *   - listing your own blocks
 *   - auth gates
 */
class UserBlockTest extends TestCase
{
    use RefreshDatabase;

    /** No auth → 401. */
    #[Test]
    public function toggle_block_requires_auth(): void
    {
        $target = User::factory()->create();
        $this->postJson("/api/block/user/{$target->id}")->assertStatus(401);
    }

    /**
     * First call (no prior block) creates a `user_blocks` row AND
     * cascades through any existing friendship + pending requests.
     * Without that cascade, blocking would leave stale UX artifacts
     * (the blocked user keeps showing up in the chat list).
     */
    #[Test]
    public function toggle_block_creates_a_row_and_tears_down_friendship_on_first_call(): void
    {
        $user = User::factory()->create();
        $target = User::factory()->create();

        DB::table('friends')->insert([
            'user_id' => $user->id,
            'friend_id' => $target->id,
            'became_friends_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        FriendRequest::factory()->create([
            'sender_id' => $user->id,
            'receiver_id' => $target->id,
        ]);

        $resp = $this->actingAs($user, 'api')->postJson("/api/block/user/{$target->id}");

        $resp->assertOk();
        $this->assertDatabaseHas('user_blocks', [
            'user_id' => $user->id,
            'block_user_id' => $target->id,
        ]);
        $this->assertDatabaseMissing('friends', [
            'user_id' => $user->id,
            'friend_id' => $target->id,
        ]);
        $this->assertDatabaseMissing('friend_requests', [
            'sender_id' => $user->id,
            'receiver_id' => $target->id,
        ]);
    }

    /**
     * Second call (block already exists) is the "unblock" toggle.
     * The row is removed; no other side effects (friendship is not
     * re-created — once severed, they have to re-friend).
     */
    #[Test]
    public function toggle_block_removes_the_row_on_second_call(): void
    {
        $user = User::factory()->create();
        $target = User::factory()->create();

        UserBlock::create([
            'user_id' => $user->id,
            'block_user_id' => $target->id,
        ]);

        $resp = $this->actingAs($user, 'api')->postJson("/api/block/user/{$target->id}");

        $resp->assertOk();
        $this->assertDatabaseMissing('user_blocks', [
            'user_id' => $user->id,
            'block_user_id' => $target->id,
        ]);
    }

    /** Blocking a non-existent user → 404. */
    #[Test]
    public function toggle_block_returns_404_for_unknown_target(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/block/user/999999');

        $resp->assertStatus(404);
    }

    /** Blocking yourself is nonsense → 400. */
    #[Test]
    public function toggle_block_rejects_self(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson("/api/block/user/{$user->id}");

        $resp->assertStatus(400);
    }

    /**
     * Privacy guard: blocked list is scoped to the auth user. Seeded
     * a block by `me` and a block by someone else — only mine shows
     * up in the response body.
     */
    #[Test]
    public function blocked_users_list_returns_my_blocks(): void
    {
        $me = User::factory()->create();
        $other = User::factory()->create();
        $blocked = User::factory()->create();
        $blocked2 = User::factory()->create();

        UserBlock::create([
            'user_id' => $me->id,
            'block_user_id' => $blocked->id,
        ]);
        UserBlock::create([
            'user_id' => $other->id,
            'block_user_id' => $blocked2->id,
        ]);

        $resp = $this->actingAs($me, 'api')->getJson('/api/block/list');
        $resp->assertOk();

        // Collection shape varies; substring check on the full body confirms
        // the user only sees their own block.
        $body = json_encode($resp->json());
        $this->assertStringContainsString((string) $blocked->id, $body);
        $this->assertStringNotContainsString('"block_user_id":'.$blocked2->id, $body);
    }

    /** No auth → 401. */
    #[Test]
    public function blocked_users_list_requires_auth(): void
    {
        $this->getJson('/api/block/list')->assertStatus(401);
    }
}
