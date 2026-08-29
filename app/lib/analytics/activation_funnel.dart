import 'package:flutter/foundation.dart';
import 'package:reacti_app/analytics/analytics_locator.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';

/// The new-user funnel, from first launch to a reaction coming back.
///
/// The one number the whole onboarding effort turns on: what fraction of new
/// accounts reach the point of the product, and how long it took them. Day-one
/// completion of a meaningful first action is the strongest known predictor of
/// whether someone is still here a month later, so each step below reports how
/// long it took **from first launch** rather than only that it happened.
///
/// Every milestone fires **once per install**. A funnel that double-counts is
/// worse than no funnel: the rates it produces look plausible and are wrong.
///
/// Nothing here identifies anyone. The events carry a step name and an elapsed
/// time, and inherit the same ambient context as every other event.
class ActivationFunnel {
  const ActivationFunnel._();

  /// Records the first-launch timestamp if this is the first launch.
  ///
  /// Safe to call on every launch; only the first write sticks. Called from
  /// `main()` before anything else can report a milestone, so no step can be
  /// measured against a clock that has not started.
  static Future<void> ensureStarted() async {
    try {
      if (appData.read(kKeyFirstLaunchAt) != null) return;
      await appData.write(kKeyFirstLaunchAt, DateTime.now().toIso8601String());
    } catch (_) {
      // Storage unavailable. Measurement is never worth breaking a launch for.
    }
  }

  /// Milliseconds since first launch, or null when the clock never started.
  ///
  /// Null rather than zero: an install that predates this code has no first
  /// launch recorded, and reporting zero would put a fake instant conversion
  /// into the funnel.
  static int? _sinceFirstLaunch() {
    final raw = _read(kKeyFirstLaunchAt);
    if (raw is! String) return null;
    final started = DateTime.tryParse(raw);
    if (started == null) return null;
    final elapsed = DateTime.now().difference(started);
    // A clock that moved backwards is not evidence of a fast conversion.
    return elapsed.isNegative ? null : elapsed.inMilliseconds;
  }

  /// Whether [milestone] has already been reported on this install.
  static bool reached(String milestone) {
    try {
      final done = appData.read(kKeyActivationMilestones);
      return done is List && done.contains(milestone);
    } catch (_) {
      // Unknown, so report nothing rather than risk a duplicate.
      return true;
    }
  }

  /// Reports [event] once per install, with time since first launch attached.
  ///
  /// [extra] adds event-specific properties. Returns without tracking when the
  /// milestone has already been reported.
  static Future<void> reach(
    String event, {
    Map<String, Object?> extra = const {},
  }) async {
    if (reached(event)) return;

    try {
      final done = appData.read(kKeyActivationMilestones);
      final updated = <String>[
        if (done is List) ...done.map((e) => e.toString()),
        event,
      ];
      // Written BEFORE tracking: a crash between the two loses one event, which
      // is a rounding error. The other order double-counts on every retry, which
      // quietly inflates every rate computed from it.
      await appData.write(kKeyActivationMilestones, updated);

      final elapsed = _sinceFirstLaunch();
      analytics.track(event, {
        if (elapsed != null) Props.msSinceFirstLaunch: elapsed,
        ...extra,
      });
    } catch (_) {
      // Every call site is on a real user path: a send, an accept, a signup.
      // Measurement must never be the thing that breaks one.
    }
  }

  /// Reads [key], or null when storage is unavailable.
  static Object? _read(String key) {
    try {
      return appData.read(key);
    } catch (_) {
      return null;
    }
  }

  /// Clears the funnel state. For tests only.
  static Future<void> resetForTest() async {
    await appData.remove(kKeyFirstLaunchAt);
    await appData.remove(kKeyActivationMilestones);
  }

  /// Whether [milestone] is recorded, without the fail-closed guard.
  ///
  /// For tests only: [reached] answers `true` when storage is unavailable so a
  /// broken store cannot cause a double count, which would make a genuine
  /// "not yet" indistinguishable from an error.
  @visibleForTesting
  static bool reachedRaw(String milestone) {
    final done = appData.read(kKeyActivationMilestones);
    return done is List && done.contains(milestone);
  }
}
