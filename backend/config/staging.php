<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Staging-only data hygiene
    |--------------------------------------------------------------------------
    |
    | These settings drive the `chat:prune-stale-staging` command, which
    | hard-deletes old chat/group messages, reactions and their media so the
    | staging environment doesn't accumulate test data forever.
    |
    | SAFETY: this is staging-only by design and must NEVER affect production.
    | Two independent gates protect it (the command no-ops unless BOTH pass):
    |   1. `prune_enabled` — an explicit opt-in switch that is set ONLY in the
    |      staging server's .env (STAGING_PRUNE_ENABLED=true). It defaults to
    |      false everywhere else (production, local, CI).
    |   2. `prune_host` — a positive identity allowlist: the command only runs
    |      when the app is actually serving this host. Production serves
    |      `reacti.io`, which does not match `staging.reacti.io`, so the command
    |      aborts there even if the switch were somehow turned on.
    |
    */

    // Master opt-in. False unless the staging .env explicitly sets it.
    'prune_enabled' => env('STAGING_PRUNE_ENABLED', false),

    // Anything created strictly before (now - this many hours) is pruned.
    'prune_hours' => (int) env('STAGING_PRUNE_HOURS', 24),

    // The ONLY host on which pruning may run. The command compares this to the
    // host of config('app.url'); production (reacti.io) never matches.
    'prune_host' => env('STAGING_PRUNE_HOST', 'staging.reacti.io'),
];
