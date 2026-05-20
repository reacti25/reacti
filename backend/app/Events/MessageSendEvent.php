<?php

namespace App\Events;

use App\Http\Resources\ChatResource;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast event fired when a new message is sent in a 1:1 chat.
 *
 * This event is load-bearing for the patent-protected flow: every chat
 * message — including the `type: "reaction"` upload produced by the
 * silent front-camera recording — is broadcast through it so both
 * participants' clients update live.
 *
 * Implements {@see ShouldBroadcastNow} for synchronous delivery, and
 * resolves the {@see ChatResource} into a plain array at construction
 * time so the serialized payload is queue/broadcast safe.
 *
 * Broadcasts on three private channels: `chat-room.{roomId}`,
 * `chat-receiver.{receiverId}` and `chat-sender.{senderId}`.
 */
class MessageSendEvent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /** @var mixed Original chat model (retained for reference; broadcast uses). */
    public $chat;

    /** @var array Resolved chat resource as a plain array, used as the broadcast body. */
    public $payload;

    /**
     * Create a new event instance.
     *
     * Resolves the chat into a plain array immediately so the broadcast
     * payload does not depend on lazy model state.
     *
     * @param  mixed  $chat  The persisted chat message model.
     */
    public function __construct($chat)
    {
        // Convert ChatResource → clean array
        $resource = new ChatResource($chat);

        // Convert to array manually
        $this->payload = $resource->resolve();
    }

    // public function broadcastOn(): array
    // {
    //     return [
    //         new PrivateChannel("chat-room.{$this->chat->room_id}"),
    //         new PrivateChannel("chat-receiver.{$this->chat->receiver_id}"),
    //         new PrivateChannel("chat-sender.{$this->chat->sender_id}")
    //     ];
    // }

    /**
     * Get the channels the event should broadcast on.
     *
     * Sends to the shared room channel plus per-user receiver and sender
     * channels so both participants update their chat list even if they
     * are not currently viewing the room. Channel IDs are read from the
     * resolved payload rather than the model.
     *
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel("chat-room.{$this->payload['room_id']}"),
            new PrivateChannel("chat-receiver.{$this->payload['receiver_id']}"),
            new PrivateChannel("chat-sender.{$this->payload['sender_id']}"),
        ];
    }

    //
    // public function broadcastWith(): array
    // {
    //     return [
    //         'chat' => new ChatResource($this->chat),
    //     ];
    // }

    /**
     * Get the data to broadcast.
     *
     * @return array Payload with the resolved `chat` resource array.
     */
    public function broadcastWith(): array
    {
        return [
            'chat' => $this->payload,
        ];
    }
}
