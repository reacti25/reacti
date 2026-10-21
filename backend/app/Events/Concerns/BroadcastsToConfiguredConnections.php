<?php

namespace App\Events\Concerns;

/**
 * Send the event to every connection in `broadcasting.fanout` instead of
 * only the default one.
 *
 * Why: while the app moves from the old agency's realtime server to
 * `ws.reacti.io`, installs of both app versions are live at once, so the
 * backend must publish to both servers (AWS plan, step 1.3). The list comes
 * from the environment (`BROADCAST_FANOUT=reverb,reverb_legacy`); unset, the
 * default connection is used and nothing changes.
 *
 * Laravel reads `broadcastConnections()` in BroadcastEvent::handle() for
 * both queued and ShouldBroadcastNow events.
 */
trait BroadcastsToConfiguredConnections
{
    /**
     * @return array<int, string|null>
     */
    public function broadcastConnections(): array
    {
        return config('broadcasting.fanout') ?: [null];
    }
}
