import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'analytics_config.dart';
import 'analytics_service.dart';
import 'events.dart';
import 'noop_analytics_service.dart';
import 'posthog_analytics_service.dart';

/// One-time analytics wiring run during app bootstrap (`main`).
///
/// Everything here is **default-off and fail-safe**: with no keys (a plain or
/// production build, and all tests) nothing initialises and the app behaves
/// exactly as before. Every step is wrapped so analytics can never break or
/// delay startup.
class AnalyticsBootstrap {
  AnalyticsBootstrap._();

  /// Selects the [AnalyticsService] implementation for the current build:
  /// PostHog-backed when analytics is enabled, otherwise a no-op. Used by DI.
  static AnalyticsService buildService() =>
      AnalyticsConfig.analyticsEnabled
          ? PostHogAnalyticsService(hashSalt: AnalyticsConfig.hashSalt)
          : NoopAnalyticsService(hashSalt: AnalyticsConfig.hashSalt);

  /// Initialises the PostHog SDK when enabled. No-op (and never throws) when
  /// disabled or if setup fails. Autocapture/lifecycle/session-replay are all
  /// OFF: we emit our own catalog events and never record screens (privacy).
  static Future<void> initPostHog() async {
    if (!AnalyticsConfig.analyticsEnabled) return;
    try {
      final config =
          PostHogConfig(AnalyticsConfig.posthogKey)
            ..host = AnalyticsConfig.posthogHost
            // We emit app_open / screen_view ourselves, through the allowlist.
            ..captureApplicationLifecycleEvents = false
            // Never record the screen — this is a face-recording app.
            ..sessionReplay = false
            ..debug = false;
      await Posthog().setup(config);
    } catch (_) {
      // Analytics must never break startup.
    }
  }

  /// Runs [runner] (the `runApp` call), wrapping it in Sentry when a DSN is
  /// configured so errors/performance are captured. When Sentry is disabled, or
  /// if init fails, [runner] still runs — startup is never blocked.
  static Future<void> runAppGuarded(VoidCallback runner) async {
    if (!AnalyticsConfig.sentryEnabled) {
      runner();
      return;
    }
    try {
      await SentryFlutter.init((options) {
        options.dsn = AnalyticsConfig.sentryDsn;
        options.environment = AnalyticsConfig.env;
        options.tracesSampleRate = AnalyticsConfig.tracesSampleRate;
        // Privacy: never attach PII (request bodies, user data) to events.
        options.sendDefaultPii = false;
      }, appRunner: runner);
    } catch (_) {
      runner();
    }
  }

  /// Emits the `app_open` event with the cold-start duration measured by
  /// [startup] (started at the top of `main`). Call from a post-first-frame
  /// callback so the measurement reflects time-to-first-frame.
  static void trackAppOpen(AnalyticsService analytics, Stopwatch startup) {
    try {
      analytics.track(Events.appOpen, {
        Props.coldStartMs: startup.elapsedMilliseconds,
        Props.isColdStart: true,
      });
    } catch (_) {
      // Fire-and-forget.
    }
  }
}
