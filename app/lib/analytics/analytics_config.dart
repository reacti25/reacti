// ignore_for_file: constant_identifier_names

/// Build-time configuration for analytics (PostHog + Sentry).
///
/// Mirrors the `BASE_URL` / `RealtimeConfig` pattern: every value is resolved at
/// build time from a `--dart-define`, with **empty defaults**. This is Phase 0
/// scaffolding — the config seam only; the [AnalyticsService] that consumes it
/// lands in Phase 1.
///
/// **Default-off by design.** With no defines, [posthogKey] / [sentryDsn] are
/// empty and [analyticsEnabled] / [sentryEnabled] are `false`, so a plain
/// `flutter build`/`flutter run` (and the production App Store build) ship with
/// analytics **disabled**. Analytics only activates when a build deliberately
/// supplies the keys — which guarantees no behaviour change and that nothing
/// reaches the production analytics project until a prod build is explicitly
/// configured. The staging CI build passes the staging keys via `--dart-define`.
///
/// No secrets live in this file or the repo: the keys come from the CI build's
/// `--dart-define` flags (sourced from GitHub secrets), per env.
///
/// Examples:
///   * production/plain (default): analytics OFF (no keys)
///   * staging CI:
///     flutter build ipa \
///       --dart-define=ANALYTICS_ENV=staging \
///       --dart-define=POSTHOG_KEY=phc_xxx \
///       --dart-define=POSTHOG_HOST=https://eu.i.posthog.com \
///       --dart-define=SENTRY_DSN=https://xxx.ingest.de.sentry.io/yyy
class AnalyticsConfig {
  /// Private constructor — this class is a namespace and is never instantiated.
  AnalyticsConfig._();

  /// Environment label, from `--dart-define=ANALYTICS_ENV`.
  ///
  /// `staging` or `production`. Labels events and selects the env's project so
  /// staging and prod data never mix. Defaults to `production` to match the
  /// "plain build = production identity" convention; but with no keys supplied
  /// analytics stays disabled regardless, so a default build emits nothing.
  static const String env = String.fromEnvironment(
    "ANALYTICS_ENV",
    defaultValue: "production",
  );

  /// PostHog project API key, from `--dart-define=POSTHOG_KEY`. Empty = disabled.
  static const String posthogKey = String.fromEnvironment("POSTHOG_KEY");

  /// PostHog ingestion host, from `--dart-define=POSTHOG_HOST`. Defaults to the
  /// **EU** cloud region (data residency requirement of the plan).
  static const String posthogHost = String.fromEnvironment(
    "POSTHOG_HOST",
    defaultValue: "https://eu.i.posthog.com",
  );

  /// Sentry DSN, from `--dart-define=SENTRY_DSN`. Empty = disabled.
  static const String sentryDsn = String.fromEnvironment("SENTRY_DSN");

  /// Sentry performance trace sample rate (0.0–1.0), from
  /// `--dart-define=SENTRY_TRACES_SAMPLE_RATE`. Defaults to a light 10% so
  /// tracing never dominates a release build.
  static const double tracesSampleRate = 0.1;

  /// Whether product analytics (PostHog) should initialise. False unless a key
  /// was supplied — the default-off guarantee.
  static bool get analyticsEnabled => posthogKey.isNotEmpty;

  /// Whether error/performance reporting (Sentry) should initialise. False
  /// unless a DSN was supplied.
  static bool get sentryEnabled => sentryDsn.isNotEmpty;

  /// True only for the staging environment — handy for guarding staging-only
  /// behaviour and for asserting in tests that prod is never the default target.
  static bool get isStaging => env == "staging";
}
