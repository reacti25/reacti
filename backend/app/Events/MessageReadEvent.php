<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast event fired when a user reads the messages in a room.
 *
 * This event is load-bearing for the patent-protected flow: it is
 * dispatched after the `mark-viewed` API call succeeds, signalling that
 * a recipient has opened the conversation. Clients use it to update
 * read receipts, and on the recipient's side this read state is what
 * gates the silent front-camera recording trigger.
 *
 * Broadcasts on the private channel `chat-room.{roomId}` under the event
 * name `MessageReadEvent`.
 *
 * Implements {@see ShouldBroadcastNow} (synchronous), like
 * {@see MessageSendEvent}: the "seen" signal must reach the sender even when
 * no queue worker is running (staging has none). A queued event would never
 * deliver there, so read receipts would silently never update live.
 */
class MessageReadEvent implements ShouldBroadcastNow
{
    use Dispatchable, SerializesModels;

    /** @var mixed ID of the room whose messages were read. */
    public $roomId;

    /** @var mixed ID of the user who read the messages. */
    public $userId;

    /**
     * Create a new event instance.
     *
     * @param  mixed  $roomId  ID of the room to notify.
     * @param  mixed  $userId  ID of the user who read the messages.
     */
    public function __construct($roomId, $userId)
    {
        $this->roomId = $roomId;
        $this->userId = $userId;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [new PrivateChannel('chat-room.'.$this->roomId)];
    }

    /**
     * The event's broadcast name.
     *
     * @return string The client-side event name (`MessageReadEvent`).
     */
    public function broadcastAs(): string
    {
        return 'MessageReadEvent';
    }
}
