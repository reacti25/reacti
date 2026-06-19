import 'dart:async';

import 'package:get_storage/get_storage.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../constants/app_constants.dart';
import '../networks/auth_token_store.dart';
import '../networks/dio/dio.dart';
import '../networks/endpoints.dart';

/// Persists the opt-out preference to the backend so it is honoured
/// server-side and across devices.
///
/// Receives the new [optedOut] state. Implementations are best-effort and must
/// not throw into the UI. The default ([AnalyticsConsent.syncOptOutToBackend])
/// POSTs to [EndPoints.analyticsOptOut] when a session exists; tests inject a
/// recording fake instead.
typedef OptOutBackendSync = Future<void> Function(bool optedOut);

/// Owns the user's analytics opt-out preference.
///
/// Backed by [GetStorage] under [kKeyAnalyticsOptOut]. When the user opts out,
/// nothing is emitted: the [AnalyticsService] gate drops all events (and Sentry
/// is gated the same way), the PostHog SDK itself is disabled so it stores or
/// sends nothing, and the preference is propagated to the backend so it emits
/// no server-side event carrying this user's id either. Opting back in
/// re-enables all three. Resolved as a `get_it` singleton (see
/// `helpers/di.dart`).
class AnalyticsConsent {
  /// Creates the consent store over [storage] (defaults to the app container).
  ///
  /// [syncToBackend] persists the preference server-side; defaults to
  /// [syncOptOutToBackend] and is injectable so tests avoid real network I/O.
  AnalyticsConsent({GetStorage? storage, OptOutBackendSync? syncToBackend})
    : _storage = storage ?? GetStorage(),
      _syncToBackend = syncToBackend ?? syncOptOutToBackend;

  final GetStorage _storage;
  final OptOutBackendSync _syncToBackend;

  /// Whether the user has opted OUT of analytics. Default (absent) = opted in.
  bool get isOptedOut => _storage.read(kKeyAnalyticsOptOut) == true;

  /// Sets the opt-out preference and applies it everywhere.
  ///
  /// [optedOut] `true` disables PostHog (no storage/send), makes the
  /// [AnalyticsService] gate drop events, and persists the preference to the
  /// backend; `false` re-enables. The SDK and backend calls are best-effort —
  /// failing them must not throw into the UI. The backend sync is
  /// fire-and-forget; the `X-Analytics-Opt-Out` header carries the immediate
  /// case meanwhile.
  Future<void> setOptedOut(bool optedOut) async {
    await _storage.write(kKeyAnalyticsOptOut, optedOut);
    try {
      if (optedOut) {
        await Posthog().disable();
      } else {
        await Posthog().enable();
      }
    } catch (_) {
      // SDK may be uninitialised (analytics disabled build) — the storage flag
      // is the source of truth the gate reads either way.
    }
    unawaited(_syncToBackend(optedOut));
  }

  /// Default backend sync: POST the preference to [EndPoints.analyticsOptOut].
  ///
  /// No-op when signed out (no session to attach the flag to — the header
  /// covers any anonymous edge case). Best-effort: a failed POST is swallowed,
  /// since the persisted local flag and the per-request header keep the backend
  /// converging on the next authenticated call.
  static Future<void> syncOptOutToBackend(bool optedOut) async {
    if (AuthTokenStore.instance.token == null) {
      return;
    }
    try {
      await postHttp(EndPoints.analyticsOptOut(), {'opted_out': optedOut});
    } catch (_) {
      // Best-effort — the header reconciles the backend regardless.
    }
  }
}
