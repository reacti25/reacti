<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast event fired when a reaction is recorded against a message.
 *
 * This event is load-bearing for the patent-protected reaction flow: when
 * a recipient opens a media message, the silent front-camera recording is
 * uploaded as a `type: "reaction"` message, and this event pushes the
 * updated running reaction count to everyone in the room so the original
 * sender sees the reaction land live.
 *
 * Broadcasts on the private channel `chat-room.{roomId}` under the event
 * name `MessageReactionEvent`.
 */
class MessageReactionEvent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /** @var mixed ID of the message that received the reaction. */
    public $chatId;

    /** @var mixed ID of the room the reacted-to message belongs to. */
    public $roomId;

    /** @var mixed ID of the user who reacted. */
    public $userId;

    /** @var mixed The reaction payload/message itself. */
    public $reaction;

    /** @var mixed Running tally of reactions for the target message. */
    public $reactionCounts;

    /**
     * Create a new event instance.
     *
     * @param  mixed  $chatId  ID of the message being reacted to.
     * @param  mixed  $roomId  ID of the room to notify.
     * @param  mixed  $userId  ID of the reacting user.
     * @param  mixed  $reaction  The reaction data.
     * @param  mixed  $reactionCounts  Updated reaction count for the message.
     */
    public function __construct($chatId, $roomId, $userId, $reaction, $reactionCounts)
    {
        $this->chatId = $chatId;
        $this->roomId = $roomId;
        $this->userId = $userId;
        $this->reaction = $reaction;
        $this->reactionCounts = $reactionCounts;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('chat-room.'.$this->roomId),
        ];
    }

    /**
     * The event's broadcast name.
     *
     * @return string The client-side event name (`MessageReactionEvent`).
     */
    public function broadcastAs(): string
    {
        return 'MessageReactionEvent';
    }
}
