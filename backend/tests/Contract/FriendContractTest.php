<?php

namespace Tests\Contract;

use App\Models\Friend;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;

/**
 * Contract tests for the friend endpoints the iOS app depends on for its
 * contacts and friend-request screens.
 *
 * Locks the response shape of the friend list and the send-friend-request
 * endpoints so a backend change that renames, drops, retypes, or nulls a
 * field these return — the class of bug that emptied every private chat on
 * 2026-05-23 — fails here before it can reach the live app.
 */
class FriendContractTest extends ContractTestCase
{
    use RefreshDatabase;

    /** GET /api/friends/list matches the friends-list contract. */
    #[Test]
    public function friend_list_matches_contract(): void
    {
        $user = User::factory()->create();
        $friend = User::factory()->create();
        // friendList collects ids from both sides, so a single row suffices.
        Friend::create([
            'user_id' => $user->id,
            'friend_id' => $friend->id,
            'became_friends_at' => now(),
        ]);

        $response = $this->actingAs($user, 'api')->getJson('/api/friends/list');

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'friends-list');
    }

    /** POST /api/friends/send-request matches the send-request contract. */
    #[Test]
    public function send_friend_request_matches_contract(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();

        $response = $this->actingAs($sender, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $receiver->id]);

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'friend-request-send');
    }
}
