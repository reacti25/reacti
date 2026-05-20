<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast event fired when a user's online/offline presence changes.
 *
 * Dispatched whenever a user connects or disconnects so other clients can
 * show accurate presence indicators and "last seen" timestamps.
 *
 * Broadcasts on the public {@see Channel} `user-status` (not private —
 * presence is shared globally) under the event name `UserOnlineEvent`.
 */
class UserOnlineEvent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /** @var mixed ID of the user whose presence changed. */
    public $userId;

    /** @var mixed Whether the user is now online (true) or offline (false). */
    public $isOnline;

    /**
     * Create a new event instance.
     *
     * @param  mixed  $userId  ID of the user whose presence changed.
     * @param  mixed  $isOnline  New online state.
     */
    public function __construct($userId, $isOnline)
    {
        $this->userId = $userId;
        $this->isOnline = $isOnline;
    }

    /**
     * Get the channel the event should broadcast on.
     *
     * @return \Illuminate\Broadcasting\Channel The public `user-status` channel.
     */
    public function broadcastOn()
    {
        return new Channel('user-status');
    }

    /**
     * The event's broadcast name.
     *
     * @return string The client-side event name (`UserOnlineEvent`).
     */
    public function broadcastAs()
    {
        return 'UserOnlineEvent';
    }

    /**
     * Get the data to broadcast.
     *
     * The `last_activity_at` timestamp is generated at broadcast time so
     * clients can render an accurate "last seen" value.
     *
     * @return array Payload with `user_id`, `is_online` and `last_activity_at`.
     */
    public function broadcastWith()
    {
        return [
            'user_id' => $this->userId,
            'is_online' => $this->isOnline,
            'last_activity_at' => now()->toIso8601String(),
        ];
    }
}
