// Tests for AnalyticsConfig — the Phase 0 build-time config seam.
//
// The critical guarantee these lock down: with no --dart-define keys (which is
// the case in `flutter test`, a plain build, and the production App Store
// build), analytics is DISABLED. This is what enforces "no behaviour change"
// and "nothing reaches prod analytics until a prod build is explicitly
// configured". The defines are compile-time constants, so the defaults are
// exactly what a keyless build sees.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_config.dart';

void main() {
  group('AnalyticsConfig defaults (no --dart-define)', () {
    test('product analytics is disabled when no PostHog key is supplied', () {
      expect(AnalyticsConfig.posthogKey, isEmpty);
      expect(AnalyticsConfig.analyticsEnabled, isFalse);
    });

    test('Sentry is disabled when no DSN is supplied', () {
      expect(AnalyticsConfig.sentryDsn, isEmpty);
      expect(AnalyticsConfig.sentryEnabled, isFalse);
    });

    test('PostHog host defaults to the EU cloud region', () {
      expect(AnalyticsConfig.posthogHost, 'https://eu.i.posthog.com');
    });

    test('env defaults to production and is not staging by default', () {
      expect(AnalyticsConfig.env, 'production');
      expect(AnalyticsConfig.isStaging, isFalse);
    });

    test('traces sample rate is a light, valid fraction', () {
      expect(AnalyticsConfig.tracesSampleRate, inInclusiveRange(0.0, 1.0));
      expect(AnalyticsConfig.tracesSampleRate, lessThanOrEqualTo(0.2));
    });
  });
}
