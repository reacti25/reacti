<?php

namespace Tests\Feature\Events;

use App\Events\MessageDeletedEvent;
use App\Models\Chat;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Locks the realtime side of chat-message deletion.
 *
 * The HTTP/DB side is exercised by ChatControllerTest. Here we only
 * care that `MessageDeletedEvent` fires when the owner deletes their
 * own message, and that *no* event fires when someone who doesn't
 * own the message tries to delete it.
 *
 * The event carries (chatId, roomId, deleteType) — clients use roomId
 * to scope their listeners to the right chat-room channel.
 */
class MessageDeletedEventTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Happy path: the owner of a chat deletes it via the API and the
     * MessageDeletedEvent broadcast fires exactly once with the right
     * payload.
     */
    #[Test]
    public function deleting_a_message_broadcasts_message_deleted_event(): void
    {
        Event::fake([MessageDeletedEvent::class]);

        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
        ]);

        $resp = $this->actingAs($alice, 'api')->deleteJson(
            '/api/auth/chat/delete/chat/messages',
            ['message_id' => $chat->id],
        );

        $resp->assertOk();
        $resp->assertJsonPath('success', true);

        Event::assertDispatched(
            MessageDeletedEvent::class,
            fn (MessageDeletedEvent $event): bool => (int) $event->chatId === $chat->id
                && (int) $event->roomId === $chat->room_id
                && $event->deleteType === 'for_everyone',
        );
        Event::assertDispatchedTimes(MessageDeletedEvent::class, 1);
    }

    /**
     * Permission path: a user who is neither sender nor receiver of a
     * chat hits 404 from the controller, and crucially no
     * MessageDeletedEvent leaks out to subscribers of the room. If we
     * broadcast on a failed delete, clients would update their UI for
     * a message that didn't actually move.
     */
    #[Test]
    public function deleting_a_message_the_user_does_not_own_does_not_broadcast(): void
    {
        Event::fake([MessageDeletedEvent::class]);

        $alice    = User::factory()->create();
        $bob      = User::factory()->create();
        $stranger = User::factory()->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
        ]);

        $resp = $this->actingAs($stranger, 'api')->deleteJson(
            '/api/auth/chat/delete/chat/messages',
            ['message_id' => $chat->id],
        );

        $resp->assertStatus(404);
        Event::assertNotDispatched(MessageDeletedEvent::class);
    }
}
