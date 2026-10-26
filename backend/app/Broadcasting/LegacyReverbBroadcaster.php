<?php

namespace App\Broadcasting;

use Illuminate\Broadcasting\Broadcasters\PusherBroadcaster;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * The old agency's Reverb server, best effort only.
 *
 * Listed second in `BROADCAST_FANOUT` during the transition to
 * `ws.reacti.io`. If that box is slow or gone, a thrown exception would fail
 * the user's request (ShouldBroadcastNow events) or make the queue retry and
 * re-send the event to our own server (queued events). So this driver never
 * throws: it logs and moves on. Removed with the legacy connection two weeks
 * after app 1.8.1 is live.
 */
class LegacyReverbBroadcaster extends PusherBroadcaster
{
    public function broadcast(array $channels, $event, array $payload = []): void
    {
        try {
            parent::broadcast($channels, $event, $payload);
        } catch (Throwable $e) {
            Log::warning('Legacy realtime server unreachable, event not mirrored', [
                'event' => $event,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
