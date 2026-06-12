<?php

namespace Tests\Contract;

use App\Events\GroupMessageSendEvent;
use App\Events\MessageReactionEvent;
use App\Events\MessageSendEvent;
use App\Models\Chat;
use App\Models\GroupMessage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;

/**
 * Contract tests for the Pusher broadcast payloads the iOS app binds to.
 *
 * The realtime events are a second wire surface the live app parses (the
 * patent reaction lands live through them), so a change to a broadcast
 * payload shape can break the live app exactly as an HTTP shape change can.
 * These pin each event's `broadcastWith()` body, reusing the same
 * `ContractMatcher`. The payload is JSON round-tripped first so any nested
 * API Resource is resolved to the plain array the client actually receives.
 *
 * The 1:1 and group send events deliberately broadcast the same shapes as
 * their REST counterparts (`broadcast-message-send` mirrors `chat-send`,
 * `broadcast-group-message-send` mirrors `group-send`), which is the
 * property the live app relies on.
 */
class BroadcastContractTest extends ContractTestCase
{
    use RefreshDatabase;

    /**
     * Resolve an event's broadcast payload to the plain array the client
     * receives over the wire (resolving any nested API Resource).
     *
     * @param  array<string,mixed>  $payload  The raw `broadcastWith()` result.
     * @return array<string,mixed>
     */
    private function wire(array $payload): array
    {
        return json_decode((string) json_encode($payload), true);
    }

    /** MessageSendEvent broadcasts the 1:1 chat in the ChatResource shape. */
    #[Test]
    public function message_send_event_payload_matches_contract(): void
    {
        $chat = Chat::factory()->create();

        $payload = $this->wire((new MessageSendEvent($chat))->broadcastWith());

        $this->assertMatchesContract($payload, 'broadcast-message-send');
    }

    /**
     * A reaction is sent as a message, so it broadcasts through the same
     * event in the same shape — the live app must parse it identically.
     */
    #[Test]
    public function message_send_event_reaction_payload_matches_contract(): void
    {
        $original = Chat::factory()->blurredMedia()->create();
        $reaction = Chat::factory()->reactionTo($original)->create();

        $payload = $this->wire((new MessageSendEvent($reaction))->broadcastWith());

        $this->assertMatchesContract($payload, 'broadcast-message-send');
        $this->assertSame('reaction', $payload['chat']['message_type']);
    }

    /** GroupMessageSendEvent broadcasts the group message in the MessageResource (broadcast) shape. */
    #[Test]
    public function group_message_send_event_payload_matches_contract(): void
    {
        $message = GroupMessage::factory()->create();

        $payload = $this->wire((new GroupMessageSendEvent($message))->broadcastWith());

        $this->assertMatchesContract($payload, 'broadcast-group-message-send');
        // Broadcast payloads are always delivered blurred (patent flow).
        $this->assertSame(1, $payload['message']['is_blurred']);
    }

    /**
     * MessageReactionEvent carries the live reaction-count update. It has no
     * `broadcastWith()`, so its public properties are the wire payload — pin
     * the client event name and the field set/types.
     */
    #[Test]
    public function message_reaction_event_payload_is_stable(): void
    {
        $event = new MessageReactionEvent(
            chatId: 11,
            roomId: 22,
            userId: 33,
            reaction: ['type' => 'reaction'],
            reactionCounts: 4,
        );

        $this->assertSame('MessageReactionEvent', $event->broadcastAs());
        $this->assertSame(11, $event->chatId);
        $this->assertSame(22, $event->roomId);
        $this->assertSame(33, $event->userId);
        $this->assertSame(4, $event->reactionCounts);
        $this->assertIsArray($event->reaction);
    }
}
