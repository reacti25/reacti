<?php

namespace App\Events;

use App\Models\GroupMessageRead;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast when one of a group message's recipients reads it and that read
 * completes "all other members" — i.e. the message is now seen by everyone.
 *
 * Lets the sender flip their text double-check live, since group read state is
 * per-member ({@see GroupMessageRead}) and otherwise only surfaces
 * on a re-fetch. Broadcasts on the SENDER's private channel
 * `group-message.{senderId}` (the same channel their group inbox already
 * subscribes to) under the event name `GroupMessageReadEvent`, carrying the
 * message id and the `seenByAll` flag.
 *
 * {@see ShouldBroadcastNow} (synchronous), matching {@see GroupMessageViewedEvent}
 * and {@see MessageReadEvent}: must deliver even with no queue worker.
 */
class GroupMessageReadEvent implements ShouldBroadcastNow
{
    use Dispatchable, SerializesModels;

    /** @var mixed Id of the message that was read. */
    public $messageId;

    /** @var mixed Id of the message's sender (the channel owner). */
    public $senderId;

    /** @var bool Whether every other member has now read the message. */
    public $seenByAll;

    /**
     * @param  mixed  $messageId  The message that was read.
     * @param  mixed  $senderId  The sender to notify (channel owner).
     * @param  bool  $seenByAll  Whether all other members have read it.
     */
    public function __construct($messageId, $senderId, $seenByAll = true)
    {
        $this->messageId = $messageId;
        $this->senderId = $senderId;
        $this->seenByAll = $seenByAll;
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
        return 'GroupMessageReadEvent';
    }
}
