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

class UserBlockTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function toggle_block_requires_auth(): void
    {
        $target = User::factory()->create();
        $this->postJson("/api/block/user/{$target->id}")->assertStatus(401);
    }

    #[Test]
    public function toggle_block_creates_a_row_and_tears_down_friendship_on_first_call(): void
    {
        $user   = User::factory()->create();
        $target = User::factory()->create();

        DB::table('friends')->insert([
            'user_id'           => $user->id,
            'friend_id'         => $target->id,
            'became_friends_at' => now(),
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);
        FriendRequest::factory()->create([
            'sender_id'   => $user->id,
            'receiver_id' => $target->id,
        ]);

        $resp = $this->actingAs($user, 'api')->postJson("/api/block/user/{$target->id}");

        $resp->assertOk();
        $this->assertDatabaseHas('user_blocks', [
            'user_id'       => $user->id,
            'block_user_id' => $target->id,
        ]);
        $this->assertDatabaseMissing('friends', [
            'user_id'   => $user->id,
            'friend_id' => $target->id,
        ]);
        $this->assertDatabaseMissing('friend_requests', [
            'sender_id'   => $user->id,
            'receiver_id' => $target->id,
        ]);
    }

    #[Test]
    public function toggle_block_removes_the_row_on_second_call(): void
    {
        $user   = User::factory()->create();
        $target = User::factory()->create();

        UserBlock::create([
            'user_id'       => $user->id,
            'block_user_id' => $target->id,
        ]);

        $resp = $this->actingAs($user, 'api')->postJson("/api/block/user/{$target->id}");

        $resp->assertOk();
        $this->assertDatabaseMissing('user_blocks', [
            'user_id'       => $user->id,
            'block_user_id' => $target->id,
        ]);
    }

    #[Test]
    public function toggle_block_returns_404_for_unknown_target(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/block/user/999999');

        $resp->assertStatus(404);
    }

    #[Test]
    public function toggle_block_rejects_self(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson("/api/block/user/{$user->id}");

        $resp->assertStatus(400);
    }

    #[Test]
    public function blocked_users_list_returns_my_blocks(): void
    {
        $me     = User::factory()->create();
        $other  = User::factory()->create();
        $blocked = User::factory()->create();
        $blocked2 = User::factory()->create();

        UserBlock::create([
            'user_id'       => $me->id,
            'block_user_id' => $blocked->id,
        ]);
        UserBlock::create([
            'user_id'       => $other->id,
            'block_user_id' => $blocked2->id,
        ]);

        $resp = $this->actingAs($me, 'api')->getJson('/api/block/list');
        $resp->assertOk();

        $ids = collect($resp->json('data.data'))->pluck('block_user_id')->all();
        $this->assertContains($blocked->id, $ids);
        $this->assertNotContains($blocked2->id, $ids);
    }

    #[Test]
    public function blocked_users_list_requires_auth(): void
    {
        $this->getJson('/api/block/list')->assertStatus(401);
    }
}
