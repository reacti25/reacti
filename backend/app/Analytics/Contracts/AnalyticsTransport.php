<?php

namespace App\Analytics\Contracts;

use App\Analytics\Analytics;

/**
 * Sink for a fully-sanitised analytics event.
 *
 * Implementations send the event to a vendor (PostHog) or drop it (null/fake).
 * The {@see Analytics} emitter has already applied the allowlist
 * and hashed the user id by the time this is called, so transports never see a
 * disallowed property or a raw user id.
 */
interface AnalyticsTransport
{
    /**
     * Send one event.
     *
     * @param  string  $event  Canonical event name.
     * @param  array<string, mixed>  $properties  Allowlisted + global properties.
     */
    public function send(string $event, array $properties): void;
}
