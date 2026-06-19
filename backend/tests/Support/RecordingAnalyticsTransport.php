<?php

namespace Tests\Support;

use App\Analytics\Contracts\AnalyticsTransport;

/**
 * Test transport that records every sent event instead of calling PostHog.
 *
 * Lets tests assert that a flow emits the right event with the right
 * allowlisted properties, with no network.
 */
final class RecordingAnalyticsTransport implements AnalyticsTransport
{
    /** @var list<array{event: string, properties: array<string, mixed>}> */
    public array $sent = [];

    public function send(string $event, array $properties): void
    {
        $this->sent[] = ['event' => $event, 'properties' => $properties];
    }

    /**
     * The recorded events with the given name.
     *
     * @return list<array{event: string, properties: array<string, mixed>}>
     */
    public function eventsNamed(string $name): array
    {
        return array_values(array_filter($this->sent, fn ($e) => $e['event'] === $name));
    }
}
