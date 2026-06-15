<?php

namespace App\Analytics\Transports;

use App\Analytics\Contracts\AnalyticsTransport;

/**
 * Analytics transport that drops every event.
 *
 * The default when analytics is disabled (no PostHog key — see
 * config/analytics.php), so the emitter is always safe to call and the server
 * behaves identically to having no analytics.
 */
final class NullTransport implements AnalyticsTransport
{
    public function send(string $event, array $properties): void
    {
        // Intentionally empty — analytics is off.
    }
}
