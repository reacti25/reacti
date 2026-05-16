<?php

namespace Tests\Feature\Friends;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * POST /api/friends/send-request — friend-request creation.
 *
 * Pins that an authenticated user can send a friend request to
 * another user and that the request is persisted as a row in the
 * `friend_requests` table linking sender and receiver.
 */
class FriendRequestTest extends TestCase
{
    use RefreshDatabase;

    /** An authenticated user sends a request → 200 and a `friend_requests` row links sender to receiver. */
    #[Test]
    public function a_user_can_send_a_friend_request(): void
    {
        $sender   = User::factory()->create();
        $receiver = User::factory()->create();

        $response = $this->actingAs($sender, 'api')->postJson(
            '/api/friends/send-request',
            ['receiver_id' => $receiver->id]
        );

        $response->assertOk();
        $response->assertJsonPath('success', true);

        $this->assertDatabaseHas('friend_requests', [
            'sender_id'   => $sender->id,
            'receiver_id' => $receiver->id,
        ]);
    }
}
