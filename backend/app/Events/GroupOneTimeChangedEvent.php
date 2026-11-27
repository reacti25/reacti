<?php

namespace App\Events;

use App\Events\Concerns\BroadcastsToConfiguredConnections;
use App\Models\GroupMember;
use App\Services\GroupOneTimeMediaService;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast when a one-time exchange in a group changed for everyone: it was
 * erased, or a member took a screenshot. Members' open group chats reload, so
 * each gets their own view back (their own links, what they already watched).
 * See {@see GroupOneTimeMediaService}.
 *
 * Broadcasts on every member's private channel `group-message.{userId}`
 * under the event name `GroupOneTimeChangedEvent`, with the `groupId`.
 */
class GroupOneTimeChangedEvent implements ShouldBroadcastNow
{
    use BroadcastsToConfiguredConnections, Dispatchable, SerializesModels;

    /** @param  int  $groupId  The group whose chat should reload. */
    public function __construct(public int $groupId) {}

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return GroupMember::where('group_id', $this->groupId)
            ->pluck('user_id')
            ->map(fn ($userId) => new PrivateChannel('group-message.'.$userId))
            ->all();
    }

    /**
     * The event's broadcast name.
     *
     * @return string The client-side event name (`GroupOneTimeChangedEvent`).
     */
    public function broadcastAs(): string
    {
        return 'GroupOneTimeChangedEvent';
    }
}
