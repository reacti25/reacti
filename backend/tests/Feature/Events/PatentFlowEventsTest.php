<?php

namespace Tests\Feature\Events;

use App\Events\MessageReadEvent;
use App\Events\MessageSendEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Locks the broadcast leg of the patent flow.
 *
 * The end-to-end Chat row / mark-viewed assertions live in
 * Tests\Feature\Patent\ReactionFlowTest. This file asserts the realtime
 * events fire across all three legs of the loop:
 *
 *   1. send media       -> MessageSendEvent
 *   2. mark-viewed      -> MessageReadEvent
 *   3. send reaction    -> MessageSendEvent
 *
 * A future refactor cannot silently drop the realtime side of the loop
 * without a test failure here.
 */
class PatentFlowEventsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    #[Test]
    public function patent_flow_broadcasts_send_read_and_reaction_events(): void
    {
        Event::fake([MessageSendEvent::class, MessageReadEvent::class]);

        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        // Step 1 — Alice sends a media message to Bob.
        $sendResp = $this->actingAs($alice, 'api')->post(
            "/api/auth/chat/send/{$bob->id}",
            [
                'text'         => '',
                'message_type' => 'normal',
                'file'         => UploadedFile::fake()->image('photo.jpg', 800, 600),
            ],
            ['Accept' => 'application/json']
        );

        $sendResp->assertOk();
        $messageId = (int) $sendResp->json('data.chat.id');
        $roomId    = (int) $sendResp->json('data.chat.room_id');

        Event::assertDispatched(
            MessageSendEvent::class,
            fn (MessageSendEvent $event): bool => (int) $event->payload['id'] === $messageId
                && (int) $event->payload['sender_id'] === $alice->id
                && (int) $event->payload['receiver_id'] === $bob->id,
        );

        // Step 2 — Bob opens the message; mark-viewed must broadcast a read
        // event so Alice's client can update the sent → viewed indicator.
        $viewResp = $this->actingAs($bob, 'api')->postJson(
            "/api/auth/chat/mark-viewed/{$messageId}"
        );

        $viewResp->assertOk();

        Event::assertDispatched(
            MessageReadEvent::class,
            fn (MessageReadEvent $event): bool => (int) $event->roomId === $roomId
                && (int) $event->userId === $bob->id,
        );
        Event::assertDispatchedTimes(MessageReadEvent::class, 1);

        // Step 3 — Bob's client uploads the silent reaction back.
        $reactResp = $this->actingAs($bob, 'api')->post(
            "/api/auth/chat/send/{$alice->id}",
            [
                'text'         => '',
                'message_type' => 'reaction',
                'reply_to_id'  => (string) $messageId,
                'file'         => UploadedFile::fake()->create('reaction.mp4', 200, 'video/mp4'),
            ],
            ['Accept' => 'application/json']
        );

        $reactResp->assertOk();
        $reactionId = (int) $reactResp->json('data.chat.id');

        Event::assertDispatched(
            MessageSendEvent::class,
            fn (MessageSendEvent $event): bool => (int) $event->payload['id'] === $reactionId
                && (int) $event->payload['sender_id'] === $bob->id
                && (int) $event->payload['receiver_id'] === $alice->id
                && $event->payload['message_type'] === 'reaction',
        );

        // Two send events total — one per send leg.
        Event::assertDispatchedTimes(MessageSendEvent::class, 2);
    }
}
