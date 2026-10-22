<?php

namespace App\Events;

use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast when a group member views another member's message.
 *
 * Lets the message's sender update their reaction "watched" dot live, since
 * group view state is otherwise per-recipient and invisible to the sender.
 * Broadcasts on the SENDER's private channel `group-message.{senderId}` (the
 * same channel their group inbox already subscribes to) under the event name
 * `GroupMessageViewedEvent`, carrying the viewed message id.
 *
 * {@see ShouldBroadcastNow} (synchronous), matching {@see GroupMessageSendEvent}
 * and {@see MessageReadEvent}: must deliver even with no queue worker.
 */
class GroupMessageViewedEvent implements ShouldBroadcastNow
{
    use Dispatchable, SerializesModels;

    /** @var mixed Id of the message that was viewed. */
    public $messageId;

    /** @var mixed Id of the group the message belongs to. */
    public $groupId;

    /** @var mixed Id of the message's sender (the channel owner). */
    public $senderId;

    /**
     * @param  mixed  $messageId  The viewed message.
     * @param  mixed  $groupId  Its group.
     * @param  mixed  $senderId  The sender to notify.
     */
    public function __construct($messageId, $groupId, $senderId)
    {
        $this->messageId = $messageId;
        $this->groupId = $groupId;
        $this->senderId = $senderId;
    }

    /**
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [new PrivateChannel('group-message.'.$this->senderId)];
    }

    /**
     * @return string The client-side event name.
     */
    public function broadcastAs(): string
    {
        return 'GroupMessageViewedEvent';
    }
}
