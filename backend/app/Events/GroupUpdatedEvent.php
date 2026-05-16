<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast event fired when a group's metadata or membership changes.
 *
 * Dispatched on group mutations (e.g. name/avatar changes, members added
 * or removed) so every client watching the group's room can refresh its
 * state. The `updateType` discriminator lets the client decide how to
 * react to the change.
 *
 * Broadcasts on the private channel `chat-room.{roomId}` under the event
 * name `GroupUpdatedEvent`.
 */
class GroupUpdatedEvent implements ShouldBroadcast
{
    use Dispatchable, SerializesModels;

    /** @var mixed ID of the chat room (group room) that was updated. */
    public $roomId;

    /** @var mixed Discriminator describing the kind of update (e.g. members, info). */
    public $updateType;

    /** @var array Extra payload describing the change, shape depends on $updateType. */
    public $data;

    /**
     * Create a new event instance.
     *
     * @param  mixed  $roomId      ID of the room whose group changed.
     * @param  mixed  $updateType  Tag identifying what changed.
     * @param  array  $data        Optional details about the change.
     */
    public function __construct($roomId, $updateType, $data = [])
    {
        $this->roomId = $roomId;
        $this->updateType = $updateType;
        $this->data = $data;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [new PrivateChannel('chat-room.' . $this->roomId)];
    }

    /**
     * The event's broadcast name.
     *
     * @return string  The client-side event name (`GroupUpdatedEvent`).
     */
    public function broadcastAs(): string
    {
        return 'GroupUpdatedEvent';
    }
}
