import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'analytics_config.dart';
import 'analytics_identity.dart';
import 'events.dart';

/// Ambient, per-launch context attached to every analytics event.
///
/// Grouped into one value object so [AnalyticsService] takes the environment,
/// platform, app version and session in one place — and so tests can supply
/// fixed values instead of the real (non-deterministic) ones.
class AnalyticsContext {
  /// Creates a context with explicit values (used by tests).
  const AnalyticsContext({
    required this.env,
    required this.platform,
    required this.appVersion,
    required this.appBuild,
    required this.sessionId,
    required this.nowIso,
  });

  /// Environment label (`production` | `staging`) — from [AnalyticsConfig.env].
  final String env;

  /// Coarse platform: `ios` | `android` | `other`.
  final String platform;

  /// Marketing version (filled once package info is wired; empty until then).
  final String appVersion;

  /// Build number (filled once package info is wired; empty until then).
  final String appBuild;

  /// Random per-app-launch id — not tied to user identity.
  final String sessionId;

  /// Returns the current time as an ISO-8601 UTC string.
  final String Function() nowIso;

  /// Builds the real runtime context: env from config, host platform, a random
  /// session id, and wall-clock timestamps. App version/build are left empty
  /// until package info is wired (a later Phase 1 step).
  factory AnalyticsContext.runtime() {
    final platform =
        Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
            ? 'android'
            : 'other';
    final sessionId = (Random().nextInt(1 << 32)).toRadixString(16);
    return AnalyticsContext(
      env: AnalyticsConfig.env,
      platform: platform,
      appVersion: '',
      appBuild: '',
      sessionId: sessionId,
      nowIso: () => DateTime.now().toUtc().toIso8601String(),
    );
  }
}

/// Vendor-agnostic analytics seam (design principle #1).
///
/// Feature code calls [track] / [identify] / [reset] and NEVER touches a vendor
/// SDK. This base class enforces the two privacy guarantees centrally so they
/// cannot be bypassed:
///
/// 1. **Allowlist** — [track] keeps only the properties listed for the event in
///    [eventAllowlist] (plus the global properties); anything else is dropped.
///    An unknown event is dropped entirely. This is the enforcement of
///    `docs/analytics/event-catalog.md`.
/// 2. **Hashed identity** — [identify] takes the RAW user id and stores only its
///    [AnalyticsIdentity.hashUserId] hash; the raw id never reaches [dispatch].
///
/// Subclasses implement [dispatch] to send the already-sanitised event to a
/// vendor (PostHog), to record it (test fake), or to do nothing (no-op).
abstract class AnalyticsService {
  /// Creates the service with an optional fixed [context] (tests) or the real
  /// runtime context.
  ///
  /// [isOptedOut] is consulted on every [track]/[identify]; when it returns
  /// `true` (the user opted out) nothing is emitted. Defaults to never
  /// opted-out; the running app wires it to the stored preference.
  AnalyticsService({
    AnalyticsContext? context,
    String hashSalt = '',
    bool Function()? isOptedOut,
  }) : _context = context ?? AnalyticsContext.runtime(),
       _hashSalt = hashSalt,
       _isOptedOut = isOptedOut ?? (() => false);

  final AnalyticsContext _context;
  final String _hashSalt;
  final bool Function() _isOptedOut;

  /// Hashed (pseudonymous) distinct id of the current user; empty when anon.
  String _distinctId = '';

  /// Records the current user from a RAW id, storing only its hash. No-op when
  /// the user has opted out.
  void identify(String rawUserId) {
    if (_isOptedOut()) return;
    _distinctId = AnalyticsIdentity.hashUserId(rawUserId, salt: _hashSalt);
  }

  /// Clears the current identity (e.g. on logout).
  void reset() => _distinctId = '';

  /// The current hashed (pseudonymous) distinct id, for vendor subclasses that
  /// must pass it to their SDK (e.g. PostHog's `identify`). Empty when anon.
  /// Never the raw user id.
  @protected
  String get currentDistinctId => _distinctId;

  /// Tracks [event] with optional [properties].
  ///
  /// Properties are filtered to the event's allowlist and merged with the global
  /// properties, then handed to [dispatch]. An event not present in
  /// [eventAllowlist] is ignored. Callers should still treat this as
  /// fire-and-forget (wrap their own side effects), but [track] itself never
  /// throws for a bad event/property — it drops them.
  void track(String event, [Map<String, Object?> properties = const {}]) {
    if (_isOptedOut()) return; // honour the user's opt-out everywhere
    final allowed = eventAllowlist[event];
    if (allowed == null) return; // unknown event — never emit ad-hoc names

    final payload = <String, Object?>{..._globalProps()};
    properties.forEach((key, value) {
      if (value != null && allowed.contains(key)) payload[key] = value;
    });

    dispatch(event, payload);
  }

  /// The global properties attached to every event.
  Map<String, Object?> _globalProps() {
    final props = <String, Object?>{
      Props.analyticsEnv: _context.env,
      Props.platform: _context.platform,
      Props.sessionId: _context.sessionId,
      Props.ts: _context.nowIso(),
    };
    if (_distinctId.isNotEmpty) props[Props.distinctId] = _distinctId;
    if (_context.appVersion.isNotEmpty) {
      props[Props.appVersion] = _context.appVersion;
    }
    if (_context.appBuild.isNotEmpty) props[Props.appBuild] = _context.appBuild;
    return props;
  }

  /// Sends an already-sanitised [event] with its final [properties] to the
  /// underlying sink. Implemented by subclasses (vendor / no-op / test fake).
  void dispatch(String event, Map<String, Object?> properties);
}
