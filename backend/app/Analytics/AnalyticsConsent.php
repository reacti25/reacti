<?php

namespace App\Analytics;

/**
 * Resolves, for the current request, whether analytics must be suppressed for
 * the acting user — the server-side honouring of the app's opt-out toggle.
 *
 * The rule: emit **no** event that carries an opted-out user's id. Anonymous
 * system events (no authenticated user, no opt-out header) still flow.
 *
 * Two signals, either of which means opted out:
 * 1. The `X-Analytics-Opt-Out: 1` request header — immediate, sent by an
 *    opted-out device on every request (covers the moment of toggling).
 * 2. The persisted `users.analytics_opt_out` flag — durable and per-user, set
 *    via the opt-out endpoint, so it holds across devices and sessions.
 */
final class AnalyticsConsent
{
    /** Whether analytics for the current request's user must be suppressed. */
    public static function isOptedOut(): bool
    {
        if (request()->header('X-Analytics-Opt-Out') === '1') {
            return true;
        }

        return (bool) (auth('api')->user()?->analytics_opt_out);
    }
}
