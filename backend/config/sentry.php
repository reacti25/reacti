<?php

/*
|--------------------------------------------------------------------------
| Sentry (errors + performance) — backend
|--------------------------------------------------------------------------
|
| Overrides on top of sentry-laravel's package defaults (the provider merges
| this with its own config). Default-off: with SENTRY_LARAVEL_DSN unset the SDK
| does not send anything, so behaviour is unchanged. Environment is tied to
| ANALYTICS_ENV so backend errors/traces are tagged staging|production exactly
| like the PostHog events. PII is never attached.
|
| Plan: docs/PLAN-analytics-stats-2026-06-14.md.
|
*/

return [
    'dsn' => env('SENTRY_LARAVEL_DSN'),

    // staging | production — mirrors config/analytics.php so app + backend share
    // the same environment label.
    'environment' => env('ANALYTICS_ENV', env('APP_ENV', 'production')),

    // Light performance tracing by default.
    'traces_sample_rate' => (float) env('SENTRY_TRACES_SAMPLE_RATE', 0.1),

    // Privacy: never attach request bodies, cookies, or user PII to events.
    'send_default_pii' => false,
];
