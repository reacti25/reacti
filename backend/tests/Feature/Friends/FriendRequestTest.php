<?php

namespace Tests\Feature\Friends;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Tymon\JWTAuth\Facades\JWTAuth;

class FriendRequestTest extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function a_user_can_send_a_friend_request(): void
    {
        $sender   = User::factory()->create();
        $receiver = User::factory()->create();

        $token = JWTAuth::fromUser($sender);

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/friends/send-request', [
                'receiver_id' => $receiver->id,
            ]);

        $response->assertOk();

        $this->assertDatabaseHas('friend_requests', [
            'sender_id'   => $sender->id,
            'receiver_id' => $receiver->id,
        ]);
    }
}
