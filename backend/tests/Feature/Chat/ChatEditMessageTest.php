<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Endpoint coverage for the 1:1 message edit route
 * (`POST /api/auth/chat/edit/{message_id}`): ownership, the 10-minute
 * window, the reaction guard, validation, and the `is_edited` flag.
 */
class ChatEditMessageTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Build a sender, receiver and their shared room.
     *
     * @return array{0: User, 1: User, 2: Room}
     */
    private function conversation(): array
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();
        $room = Room::factory()->between($sender, $receiver)->create();

        return [$sender, $receiver, $room];
    }

    /**
     * Create a message from $sender to $receiver in $room.
     */
    private function makeMessage(User $sender, User $receiver, Room $room, array $overrides = []): Chat
    {
        return Chat::factory()->create(array_merge([
            'sender_id' => $sender->id,
            'receiver_id' => $receiver->id,
            'room_id' => $room->id,
            'text' => 'original',
            'message_type' => 'normal',
        ], $overrides));
    }

    /** The sender edits their own recent message → 200, text + is_edited update. */
    #[Test]
    public function sender_can_edit_own_message_within_window(): void
    {
        [$sender, $receiver, $room] = $this->conversation();
        $chat = $this->makeMessage($sender, $receiver, $room);

        $resp = $this->actingAs($sender, 'api')
            ->postJson("/api/auth/chat/edit/{$chat->id}", ['text' => 'edited text']);

        $resp->assertOk();
        $resp->assertJsonPath('data.chat.text', 'edited text');
        $resp->assertJsonPath('data.chat.is_edited', true);
        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'text' => 'edited text']);
        $this->assertNotNull($chat->fresh()->edited_at);
    }

    /** No auth → 401. */
    #[Test]
    public function edit_requires_auth(): void
    {
        [$sender, $receiver, $room] = $this->conversation();
        $chat = $this->makeMessage($sender, $receiver, $room);

        $this->postJson("/api/auth/chat/edit/{$chat->id}", ['text' => 'x'])
            ->assertStatus(401);
    }

    /** Only the sender may edit — the receiver gets 404 and the text is unchanged. */
    #[Test]
    public function non_sender_cannot_edit(): void
    {
        [$sender, $receiver, $room] = $this->conversation();
        $chat = $this->makeMessage($sender, $receiver, $room);

        $this->actingAs($receiver, 'api')
            ->postJson("/api/auth/chat/edit/{$chat->id}", ['text' => 'hijacked'])
            ->assertStatus(404);
        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'text' => 'original']);
    }

    /** Past the 10-minute window → 422, text unchanged. */
    #[Test]
    public function cannot_edit_after_window(): void
    {
        [$sender, $receiver, $room] = $this->conversation();
        $chat = $this->makeMessage($sender, $receiver, $room);
        $chat->created_at = now()->subMinutes(11);
        $chat->save();

        $this->actingAs($sender, 'api')
            ->postJson("/api/auth/chat/edit/{$chat->id}", ['text' => 'too late'])
            ->assertStatus(422);
        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'text' => 'original']);
    }

    /** A reaction clip has no editable text → 404. */
    #[Test]
    public function cannot_edit_reaction(): void
    {
        [$sender, $receiver, $room] = $this->conversation();
        $chat = $this->makeMessage($sender, $receiver, $room, ['message_type' => 'reaction']);

        $this->actingAs($sender, 'api')
            ->postJson("/api/auth/chat/edit/{$chat->id}", ['text' => 'nope'])
            ->assertStatus(404);
    }

    /** `text` is required → 422 on empty. */
    #[Test]
    public function edit_requires_text(): void
    {
        [$sender, $receiver, $room] = $this->conversation();
        $chat = $this->makeMessage($sender, $receiver, $room);

        $this->actingAs($sender, 'api')
            ->postJson("/api/auth/chat/edit/{$chat->id}", ['text' => ''])
            ->assertStatus(422);
    }
}
