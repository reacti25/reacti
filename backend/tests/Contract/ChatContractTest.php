<?php

namespace Tests\Contract;

use App\Models\Chat;
use App\Models\Friend;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;

/**
 * Contract tests for the 1:1 chat endpoints the iOS app depends on,
 * including the patent-flow gate (mark-viewed).
 *
 * These lock the exact response shape of the chat list, conversation,
 * send, and mark-viewed endpoints. A backend change that renames, drops,
 * retypes, or nulls a field these endpoints return — the class of bug
 * that emptied every private chat on 2026-05-23 — fails here before it can
 * reach main.
 */
class ChatContractTest extends ContractTestCase
{
    use RefreshDatabase;

    private User $userA;

    private User $userB;

    private Chat $media;

    /**
     * Build a realistic two-user conversation: A and B are friends sharing
     * a room, with one text message (A->B) and one blurred media message
     * (B->A) that A — as its receiver — is allowed to mark viewed.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->userA = User::factory()->create();
        $this->userB = User::factory()->create();
        Friend::create([
            'user_id' => $this->userA->id,
            'friend_id' => $this->userB->id,
            'became_friends_at' => now(),
        ]);
        $room = Room::factory()->between($this->userA, $this->userB)->create();

        Chat::factory()->create([
            'sender_id' => $this->userA->id,
            'receiver_id' => $this->userB->id,
            'room_id' => $room->id,
            'text' => 'hi B',
            'message_type' => 'normal',
        ]);
        $this->media = Chat::factory()->blurredMedia()->create([
            'sender_id' => $this->userB->id,
            'receiver_id' => $this->userA->id,
            'room_id' => $room->id,
        ]);
    }

    /** GET /api/auth/chat/list matches the combined-chat-list contract. */
    #[Test]
    public function chat_list_matches_contract(): void
    {
        $response = $this->actingAs($this->userA, 'api')->getJson('/api/auth/chat/list');

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'chat-list');
    }

    /** GET /api/auth/chat/conversation/{id} matches the conversation contract (the 2026-05-23 endpoint). */
    #[Test]
    public function conversation_matches_contract(): void
    {
        $response = $this->actingAs($this->userA, 'api')
            ->getJson('/api/auth/chat/conversation/'.$this->userB->id);

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'chat-conversation');
    }

    /** POST /api/auth/chat/send/{id} matches the send contract. */
    #[Test]
    public function send_matches_contract(): void
    {
        $response = $this->actingAs($this->userA, 'api')
            ->postJson('/api/auth/chat/send/'.$this->userB->id, ['text' => 'sending now']);

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'chat-send');
    }

    /** POST /api/auth/chat/mark-viewed/{id} matches the mark-viewed contract (patent-flow gate). */
    #[Test]
    public function mark_viewed_matches_contract(): void
    {
        $response = $this->actingAs($this->userA, 'api')
            ->postJson('/api/auth/chat/mark-viewed/'.$this->media->id);

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'chat-mark-viewed');
    }
}
