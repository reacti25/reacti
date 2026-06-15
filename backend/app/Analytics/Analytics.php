<?php

namespace App\Analytics;

use App\Analytics\Contracts\AnalyticsTransport;
use App\Providers\AnalyticsServiceProvider;

/**
 * Server-side analytics emitter — the backend mirror of the app's
 * `AnalyticsService`. The single seam through which all server events flow;
 * domain code calls this, never a vendor SDK.
 *
 * Enforces the two privacy guarantees centrally so they cannot be bypassed:
 * 1. **Allowlist** — {@see track} keeps only the properties listed for the
 *    event in {@see AnalyticsEvents::ALLOWLIST} (plus globals); anything else is
 *    dropped, and an unknown event is not emitted.
 * 2. **Hashed identity** — the raw user id is hashed (salted SHA-256) into a
 *    pseudonymous `distinct_id`; the raw id never reaches the transport. With no
 *    salt configured, no `distinct_id` is attached (anonymous), never an
 *    unsalted reversible hash.
 *
 * Bound as a singleton in {@see AnalyticsServiceProvider} with a
 * null transport when analytics is disabled, so calling it is always safe.
 */
final class Analytics
{
    public function __construct(
        private readonly AnalyticsTransport $transport,
        private readonly string $env,
        private readonly string $salt,
    ) {}

    /**
     * Track [event] with optional allowlisted [props].
     *
     * @param  array<string, mixed>  $props
     * @param  string|null  $userId  Raw user id; hashed before use, or null/anon.
     */
    public function track(string $event, array $props = [], ?string $userId = null): void
    {
        $allowed = AnalyticsEvents::ALLOWLIST[$event] ?? null;
        if ($allowed === null) {
            return; // unknown event — never emit ad-hoc names
        }

        $payload = $this->globalProperties($userId);
        foreach ($props as $key => $value) {
            if ($value !== null && in_array($key, $allowed, true)) {
                $payload[$key] = $value;
            }
        }

        try {
            $this->transport->send($event, $payload);
        } catch (\Throwable $e) {
            // Fire-and-forget — analytics must never break the caller.
        }
    }

    /**
     * Emit `message_persisted` for a saved message.
     *
     * @param  string  $messageType  text|media|reaction
     * @param  string  $scope  private|group
     * @param  string|null  $userId  Raw sender id (hashed before emit).
     */
    public function messagePersisted(string $messageType, string $scope, ?string $userId = null): void
    {
        $this->track(
            AnalyticsEvents::MESSAGE_PERSISTED,
            ['message_type' => $messageType, 'scope' => $scope],
            $userId,
        );
    }

    /**
     * Build the global properties attached to every event.
     *
     * @return array<string, mixed>
     */
    private function globalProperties(?string $userId): array
    {
        $globals = [
            'analytics_env' => $this->env,
            'ts' => now()->toIso8601String(),
        ];
        $distinctId = $this->hashUserId($userId);
        if ($distinctId !== null) {
            $globals['distinct_id'] = $distinctId;
        }

        return $globals;
    }

    /**
     * Salted SHA-256 of the user id. Null when there is no id or no salt — we
     * never emit an unsalted, brute-forceable hash.
     */
    private function hashUserId(?string $userId): ?string
    {
        if ($userId === null || $userId === '' || $this->salt === '') {
            return null;
        }

        return hash('sha256', $this->salt.':'.$userId);
    }
}
