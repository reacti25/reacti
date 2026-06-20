<?php

namespace App\Analytics;

/**
 * Typed analytics event names and the per-event property allowlist for the
 * backend — the server-side mirror of docs/analytics/event-catalog.md and of
 * the app's `events.dart`.
 *
 * The {@see Analytics} emitter enforces this: any property not listed for an
 * event is dropped, and an unknown event is not emitted. Keep this in lockstep
 * with the catalog (a test fails the build if a disallowed property is emitted).
 */
final class AnalyticsEvents
{
    /** A chat/group message was persisted. */
    public const MESSAGE_PERSISTED = 'message_persisted';

    /**
     * A persisted media message's seal state at persist time — the server
     * mirror of the app's `media_received_seal_state`. Lets us tell a
     * "persisted unsealed at the source" bug from a "sealed correctly but
     * parsed as open on the client" bug.
     */
    public const MEDIA_PERSISTED_SEAL_STATE = 'media_persisted_seal_state';

    /** An API request completed (emitted by the metrics middleware, later slice). */
    public const API_REQUEST = 'api_request';

    /**
     * Per-event allowlist of feature property keys. Global properties
     * (analytics_env, distinct_id, ...) are added by the emitter and are not
     * listed here.
     *
     * @var array<string, list<string>>
     */
    public const ALLOWLIST = [
        self::MESSAGE_PERSISTED => ['message_type', 'scope', 'processing_ms'],
        self::MEDIA_PERSISTED_SEAL_STATE => ['seal_state', 'message_type', 'scope'],
        self::API_REQUEST => ['endpoint', 'method', 'status', 'latency_ms'],
    ];

    /**
     * Global property keys the emitter attaches to every event.
     *
     * @var list<string>
     */
    public const GLOBALS = ['analytics_env', 'distinct_id', 'ts'];
}
