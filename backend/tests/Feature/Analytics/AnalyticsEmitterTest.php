<?php

namespace Tests\Feature\Analytics;

use App\Analytics\Analytics;
use App\Analytics\AnalyticsEvents;
use Tests\Support\RecordingAnalyticsTransport;
use Tests\TestCase;

/**
 * Privacy-guard tests for the server-side Analytics emitter: it must drop
 * anything not allowlisted, never emit a raw user id, and not emit unknown
 * events. These fail the build if a disallowed property could be emitted.
 */
class AnalyticsEmitterTest extends TestCase
{
    private function emitter(RecordingAnalyticsTransport $transport, string $salt = 'test-salt'): Analytics
    {
        return new Analytics($transport, 'staging', $salt);
    }

    public function test_track_drops_properties_not_in_the_allowlist(): void
    {
        $transport = new RecordingAnalyticsTransport;
        $this->emitter($transport)->track(AnalyticsEvents::MESSAGE_PERSISTED, [
            'message_type' => 'text',
            'scope' => 'private',
            'secret' => 'leak',
            'message_text' => 'hello',
        ]);

        $props = $transport->sent[0]['properties'];
        $this->assertSame('text', $props['message_type']);
        $this->assertSame('private', $props['scope']);
        $this->assertArrayNotHasKey('secret', $props);
        $this->assertArrayNotHasKey('message_text', $props);
    }

    public function test_an_unknown_event_is_not_emitted(): void
    {
        $transport = new RecordingAnalyticsTransport;
        $this->emitter($transport)->track('totally_made_up_event', ['scope' => 'private']);
        $this->assertEmpty($transport->sent);
    }

    public function test_distinct_id_is_a_salted_hash_not_the_raw_id(): void
    {
        $transport = new RecordingAnalyticsTransport;
        $this->emitter($transport, 'secret-salt')->messagePersisted('text', 'private', '42');

        $props = $transport->sent[0]['properties'];
        $this->assertNotSame('42', $props['distinct_id']);
        $this->assertSame(hash('sha256', 'secret-salt:42'), $props['distinct_id']);
        $this->assertSame('staging', $props['analytics_env']);
    }

    public function test_no_distinct_id_is_emitted_without_a_salt(): void
    {
        $transport = new RecordingAnalyticsTransport;
        $this->emitter($transport, '')->messagePersisted('text', 'private', '42');
        $this->assertArrayNotHasKey('distinct_id', $transport->sent[0]['properties']);
    }
}
