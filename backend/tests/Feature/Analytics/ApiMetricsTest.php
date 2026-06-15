<?php

namespace Tests\Feature\Analytics;

use App\Analytics\Analytics;
use App\Analytics\AnalyticsEvents;
use Tests\Support\RecordingAnalyticsTransport;
use Tests\TestCase;

/**
 * The API-metrics middleware emits one `api_request` event per request with the
 * route pattern (no ids), method, status and latency — and never alters the
 * response.
 */
class ApiMetricsTest extends TestCase
{
    private RecordingAnalyticsTransport $transport;

    protected function setUp(): void
    {
        parent::setUp();
        $this->transport = new RecordingAnalyticsTransport;
        $this->app->instance(
            Analytics::class,
            new Analytics($this->transport, 'staging', 'salt'),
        );
    }

    public function test_an_api_request_emits_api_request_with_pattern_and_status(): void
    {
        $this->getJson('/api/check')->assertOk();

        $events = $this->transport->eventsNamed(AnalyticsEvents::API_REQUEST);
        $this->assertNotEmpty($events);

        $props = $events[0]['properties'];
        // The route PATTERN, never a concrete id.
        $this->assertSame('api/check', $props['endpoint']);
        $this->assertSame('GET', $props['method']);
        $this->assertSame(200, $props['status']);
        $this->assertIsInt($props['latency_ms']);
        $this->assertSame('staging', $props['analytics_env']);
    }

    public function test_disallowed_properties_cannot_leak_through_the_event(): void
    {
        $this->getJson('/api/check')->assertOk();

        $props = $this->transport->eventsNamed(AnalyticsEvents::API_REQUEST)[0]['properties'];
        // Only allowlisted keys (+ globals) — no raw url, query, body, ids.
        $allowed = array_merge(
            AnalyticsEvents::ALLOWLIST[AnalyticsEvents::API_REQUEST],
            AnalyticsEvents::GLOBALS,
        );
        foreach (array_keys($props) as $key) {
            $this->assertContains($key, $allowed, "Unexpected property '{$key}' on api_request");
        }
    }
}
