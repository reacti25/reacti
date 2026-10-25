<?php

namespace Tests\Feature\Events;

use App\Events\Concerns\BroadcastsToConfiguredConnections;
use App\Events\MessageReadEvent;
use App\Events\UserOnlineEvent;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * During the move from the agency's realtime server to
 * ws.reacti.io every event is published to both, and the old server can
 * never break a request or make the queue re-send an event.
 */
class BroadcastFanoutTest extends TestCase
{
    #[Test]
    public function every_broadcast_event_fans_out_to_the_configured_connections(): void
    {
        foreach (File::files(app_path('Events')) as $file) {
            $class = 'App\\Events\\'.$file->getFilenameWithoutExtension();
            $this->assertContains(BroadcastsToConfiguredConnections::class, class_uses_recursive($class), "$class must fan out");
        }

        config(['broadcasting.fanout' => ['reverb', 'reverb_legacy']]);
        $this->assertSame(['reverb', 'reverb_legacy'], (new UserOnlineEvent(1, true))->broadcastConnections());

        config(['broadcasting.fanout' => []]);
        $this->assertSame([null], (new UserOnlineEvent(1, true))->broadcastConnections(), 'unset: the default connection only');
    }

    #[Test]
    public function a_dead_legacy_server_is_logged_and_our_server_still_gets_the_event(): void
    {
        config([
            'broadcasting.fanout' => ['log', 'reverb_legacy'],
            'broadcasting.connections.reverb_legacy.key' => 'k',
            'broadcasting.connections.reverb_legacy.secret' => 's',
            'broadcasting.connections.reverb_legacy.app_id' => '1',
            'broadcasting.connections.reverb_legacy.options.host' => '127.0.0.1',
            'broadcasting.connections.reverb_legacy.options.port' => 9, // nothing listens
        ]);
        Log::spy();

        broadcast(new MessageReadEvent(1, 2)); // ShouldBroadcastNow: runs inline, would throw here

        Log::shouldHaveReceived('info')->once();    // the `log` connection (ours) got it
        Log::shouldHaveReceived('warning')->once(); // the legacy failure was swallowed
    }
}
