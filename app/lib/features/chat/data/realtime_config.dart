// ignore_for_file: constant_identifier_names

/// Single source of truth for the realtime (Pusher/websocket) connection.
///
/// Mirrors the `BASE_URL` pattern in `networks/endpoints.dart`: every value is
/// resolved at build time from a `--dart-define`, falling back to the current
/// production realtime endpoint when no define is supplied. This keeps the
/// host/port/key/auth-URL out of inline widget code (so staging and prod can
/// be pointed at different realtime servers via the CI build) **without
/// changing the live app's behaviour** — the defaults below are exactly the
/// values the live App Store app already uses.
///
/// The realtime server is a self-hosted websocket endpoint (wss on port 8081),
/// not a hosted Pusher cluster, hence the explicit host/port. The host name is
/// historical; migrating it to a `reacti.io` domain and rotating the app key
/// are deliberately deferred, app-first, follow-up steps (see `NEEDS-ACHIA.md`).
///
/// Examples:
///   * production (default):  flutter build ipa
///   * staging:               flutter build ipa --dart-define=PUSHER_HOST=staging-realtime.example --dart-define=PUSHER_KEY=...
class RealtimeConfig {
  /// Private constructor — this class is a namespace and is never instantiated.
  RealtimeConfig._();

  /// Websocket scheme, from `--dart-define=PUSHER_SCHEME`. Default `wss`.
  static const String scheme = String.fromEnvironment(
    "PUSHER_SCHEME",
    defaultValue: "wss",
  );

  /// Realtime host, from `--dart-define=PUSHER_HOST`. Default is the current
  /// production self-hosted websocket host.
  static const String host = String.fromEnvironment(
    "PUSHER_HOST",
    defaultValue: "climbiq-goonclimbers.com",
  );

  /// Realtime port, from `--dart-define=PUSHER_PORT`. Default `8081`.
  static const int port = int.fromEnvironment(
    "PUSHER_PORT",
    defaultValue: 8081,
  );

  /// Pusher app key, from `--dart-define=PUSHER_KEY`. Default is the current
  /// production key. This is a client-side broadcast key (not a server secret);
  /// rotating it is a separate, app-first step tracked in `NEEDS-ACHIA.md`.
  static const String key = String.fromEnvironment(
    "PUSHER_KEY",
    defaultValue: "d3d9ba606e9065ff0c3d1d566ccf904c",
  );

  /// Private-channel authorization endpoint, from
  /// `--dart-define=BROADCAST_AUTH_URL`. Default is the production
  /// `broadcasting/auth` URL on `reacti.io`.
  static const String authUrl = String.fromEnvironment(
    "BROADCAST_AUTH_URL",
    defaultValue: "https://reacti.io/api/broadcasting/auth",
  );
}
