import 'package:get_storage/get_storage.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../constants/app_constants.dart';

/// Owns the user's analytics opt-out preference.
///
/// Backed by [GetStorage] under [kKeyAnalyticsOptOut]. When the user opts out,
/// nothing is emitted: the [AnalyticsService] gate drops all events (and Sentry
/// is gated the same way), and the PostHog SDK itself is disabled so it stores
/// or sends nothing. Opting back in re-enables it. Resolved as a `get_it`
/// singleton (see `helpers/di.dart`).
class AnalyticsConsent {
  /// Creates the consent store over [storage] (defaults to the app container).
  AnalyticsConsent({GetStorage? storage}) : _storage = storage ?? GetStorage();

  final GetStorage _storage;

  /// Whether the user has opted OUT of analytics. Default (absent) = opted in.
  bool get isOptedOut => _storage.read(kKeyAnalyticsOptOut) == true;

  /// Sets the opt-out preference and applies it to the PostHog SDK.
  ///
  /// [optedOut] `true` disables PostHog (no storage/send) and makes the
  /// [AnalyticsService] gate drop events; `false` re-enables. The SDK call is
  /// best-effort — failing it must not throw into the UI.
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
  }
}
