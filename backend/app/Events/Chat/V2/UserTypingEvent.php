<?php

namespace App\Events\Chat\V2;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast event fired while a user is typing in a 1:1 chat (V2 API).
 *
 * Dispatched whenever a sender starts or stops typing so the recipient's
 * client can render the "typing…" indicator in real time. Implements
 * {@see ShouldBroadcastNow} so it is pushed to Pusher synchronously
 * (no queue) — typing state is only useful while it is fresh.
 *
 * Broadcasts on the recipient's private channel `user.{receiverId}`
 * under the event name `user.typing`.
 */
class UserTypingEvent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /** @var mixed ID of the user who is typing (the sender). */
    public $userId;

    /** @var mixed ID of the user who should see the typing indicator. */
    public $receiverId;

    /** @var mixed Whether the sender is currently typing (true) or stopped (false). */
    public $isTyping;

    /**
     * Create a new event instance.
     *
     * @param  array  $data  Associative array with `user_id`, `receiver_id` and `is_typing` keys.
     */
    public function __construct($data)
    {
        $this->userId = $data['user_id'];
        $this->receiverId = $data['receiver_id'];
        $this->isTyping = $data['is_typing'];
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * Targets only the recipient's private channel so the indicator is
     * delivered exclusively to the user being typed at.
     *
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel("user.{$this->receiverId}"),
        ];
    }

    /**
     * The event's broadcast name.
     *
     * @return string The client-side event name (`user.typing`).
     */
    public function broadcastAs(): string
    {
        return 'user.typing';
    }

    /**
     * Get the data to broadcast.
     *
     * Only the typing user's ID and the typing flag are sent; the
     * receiver ID is intentionally omitted since it is implicit in the channel.
     *
     * @return array Payload with `user_id` and `is_typing`.
     */
    public function broadcastWith(): array
    {
        return [
            'user_id' => $this->userId,
            'is_typing' => $this->isTyping,
        ];
    }
}
