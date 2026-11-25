<?php

namespace App\Events;

use App\Events\Concerns\BroadcastsToConfiguredConnections;
use App\Services\OneTimeMediaService;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast when the person viewing a one-time message took a screenshot of
 * it, so the sender's open chat turns that message's tile to "Screenshot
 * taken" at once. See {@see OneTimeMediaService::recordScreenshot()}.
 *
 * Broadcasts on the private channel `chat-room.{roomId}` under the event
 * name `OneTimeScreenshotEvent`, with the message id as `chatId`.
 */
class OneTimeScreenshotEvent implements ShouldBroadcastNow
{
    use BroadcastsToConfiguredConnections, Dispatchable, SerializesModels;

    /**
     * @param  int  $chatId  The one-time message that was on screen.
     * @param  int  $roomId  The room to notify.
     */
    public function __construct(public int $chatId, public int $roomId) {}

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [new PrivateChannel('chat-room.'.$this->roomId)];
    }

    /**
     * The event's broadcast name.
     *
     * @return string The client-side event name (`OneTimeScreenshotEvent`).
     */
    public function broadcastAs(): string
    {
        return 'OneTimeScreenshotEvent';
    }
}
