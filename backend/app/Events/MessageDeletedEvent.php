<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast event fired when a chat message is deleted.
 *
 * Dispatched after a message is removed so every participant in the room
 * can drop it from their view in real time. The `deleteType` indicates
 * the scope of the deletion (e.g. delete-for-me vs delete-for-everyone)
 * so clients can apply the correct UI behaviour.
 *
 * Broadcasts on the private channel `chat-room.{roomId}` under the event
 * name `MessageDeletedEvent`.
 */
class MessageDeletedEvent implements ShouldBroadcast
{
    use Dispatchable, SerializesModels;

    /** @var mixed ID of the deleted chat message. */
    public $chatId;

    /** @var mixed ID of the room the deleted message belonged to. */
    public $roomId;

    /** @var mixed Scope of the deletion (e.g. for-me / for-everyone). */
    public $deleteType;

    /**
     * Create a new event instance.
     *
     * @param  mixed  $chatId  ID of the message that was deleted.
     * @param  mixed  $roomId  ID of the room to notify.
     * @param  mixed  $deleteType  Scope of the deletion.
     */
    public function __construct($chatId, $roomId, $deleteType)
    {
        $this->chatId = $chatId;
        $this->roomId = $roomId;
        $this->deleteType = $deleteType;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [new PrivateChannel('chat-room.'.$this->roomId)];
    }

    /**
     * The event's broadcast name.
     *
     * @return string The client-side event name (`MessageDeletedEvent`).
     */
    public function broadcastAs(): string
    {
        return 'MessageDeletedEvent';
    }
}
