<?php

namespace Tests\Unit;

use Tests\TestCase;

/**
 * Tests for config/analytics.php — the Phase 0 backend config seam.
 *
 * Locks the core guarantee: with no analytics env vars set (the CI/default
 * case), analytics is DISABLED, so existing behaviour is unchanged and nothing
 * is emitted. Also pins the EU host default and the config shape the Phase 1
 * emitter will read.
 */
class AnalyticsConfigTest extends TestCase
{
    /** Analytics is off by default — no key, no emission. */
    public function test_analytics_is_disabled_when_no_posthog_key_is_set(): void
    {
        $this->assertFalse(config('analytics.enabled'));
        $this->assertNull(config('analytics.posthog.key'));
    }

    /** PostHog defaults to the EU cloud region (data-residency requirement). */
    public function test_posthog_host_defaults_to_eu_region(): void
    {
        $this->assertSame('https://eu.i.posthog.com', config('analytics.posthog.host'));
    }

    /** The config exposes the shape the Phase 1 emitter depends on. */
    public function test_config_exposes_expected_shape(): void
    {
        $this->assertIsString(config('analytics.env'));
        $this->assertIsFloat(config('analytics.sample_rate'));
        $this->assertArrayHasKey('posthog', config('analytics'));
        $this->assertArrayHasKey('sentry', config('analytics'));
        $this->assertIsFloat(config('analytics.sentry.traces_sample_rate'));
    }

    /** The user-id hash salt is not hard-coded in the repo (set per-env only). */
    public function test_hash_salt_is_not_committed(): void
    {
        $this->assertNull(config('analytics.hash_salt'));
    }
}
