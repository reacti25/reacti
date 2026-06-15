<?php

namespace App\Analytics\Transports;

use App\Analytics\Contracts\AnalyticsTransport;
use Illuminate\Support\Facades\Http;

/**
 * Sends events to PostHog's capture API.
 *
 * Fire-and-forget: the HTTP call is dispatched to run **after the response is
 * sent** (`afterResponse`) and is wrapped in try/catch, so analytics can never
 * slow or break the request. Like the app, it disables IP-based GeoIP so a
 * pseudonymous user is never pinned to a location.
 */
final class PostHogTransport implements AnalyticsTransport
{
    public function __construct(
        private readonly string $apiKey,
        private readonly string $host,
    ) {}

    public function send(string $event, array $properties): void
    {
        $payload = [
            'api_key' => $this->apiKey,
            'event' => $event,
            'distinct_id' => $properties['distinct_id'] ?? 'server',
            'properties' => array_merge($properties, ['$geoip_disable' => true]),
            'timestamp' => now()->toIso8601String(),
        ];
        $url = rtrim($this->host, '/').'/capture/';

        // Run after the response so the user's request is never delayed.
        dispatch(function () use ($url, $payload) {
            try {
                Http::timeout(3)->post($url, $payload);
            } catch (\Throwable $e) {
                // Analytics must never break a request.
            }
        })->afterResponse();
    }
}
