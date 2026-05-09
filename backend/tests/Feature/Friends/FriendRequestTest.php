<?php

namespace Tests\Feature\Friends;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class FriendRequestTest extends TestCase
{
    use RefreshDatabase;

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
