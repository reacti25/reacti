<?php

namespace Tests\Feature\Events;

use App\Events\MessageDeletedEvent;
use App\Models\Chat;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class MessageDeletedEventTest extends TestCase
{
    use RefreshDatabase;

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
