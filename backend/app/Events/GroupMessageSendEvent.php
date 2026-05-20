<?php

namespace App\Events;

use App\Http\Resources\MessageResource;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Broadcast event fired when a new message is sent in a group chat.
 *
 * Dispatched after a group message is persisted so every member's client
 * receives the message live. Implements {@see ShouldBroadcastNow} so the
 * push happens synchronously without waiting on a queue worker.
 *
 * Unlike a fixed channel, this event fans out to one private channel per
 * group member — `group-message.{userId}` — and carries the message as a
 * {@see MessageResource}. Verbose logging is emitted to aid debugging of
 * group fan-out delivery issues.
 */
class GroupMessageSendEvent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /** @var mixed The group message model being broadcast. */
    public $message;

    /**
     * Create a new event instance.
     *
     * Logs the message/group/sender IDs so group broadcast activity can
     * be traced in the application log.
     *
     * @param  mixed  $message  The persisted group message model.
     */
    public function __construct($message)
    {
        $this->message = $message;
        Log::info('Broadcasting group message event', [
            'message_id' => $this->message->id,
            'group_id' => $this->message->group_id,
            'sender_id' => $this->message->sender_id,
        ]);
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * Broadcasts to all group members privately: builds one
     * `group-message.{userId}` private channel per member (including the
     * sender, so their own session updates too). Returns an empty array
     * if the group can no longer be resolved.
     *
     * @return array<int, \Illuminate\Broadcasting\PrivateChannel>
     */
    public function broadcastOn(): array
    {
        $channels = [];
        // Eager-load members so each one gets a dedicated private channel.
        $group = $this->message->group()->with('members')->first();

        if ($group) {
            Log::info('Broadcasting to group members', [
                'group_id' => $group->id,
                'total_members' => $group->members->count(),
            ]);

            foreach ($group->members as $member) {
                $channelName = "group-message.{$member->user_id}";
                $channels[] = new PrivateChannel($channelName);

                Log::info('Adding channel', [
                    'user_id' => $member->user_id,
                    'channel' => $channelName,
                    'is_sender' => $member->user_id == $this->message->sender_id,
                ]);
            }
        }

        Log::info('Total channels', ['count' => count($channels), 'channels' => array_map(function ($ch) {
            return $ch->name;
        }, $channels)]);

        return $channels;
    }

    /**
     * Get the data to broadcast.
     *
     * Wraps the message in a {@see MessageResource} using the `broadcast`
     * variant so the client receives the same shape as the REST API.
     *
     * @return array Payload with a `message` resource.
     */
    public function broadcastWith(): array
    {
        return [
            'message' => new MessageResource($this->message, 'broadcast'),
        ];
    }

    /**
     * The event's broadcast name.
     *
     * No override is provided, so the default fully-qualified class name
     * is used as the client-side event name.
     */
}
