import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'analytics_service.dart';
import 'events.dart';

/// A [NavigatorObserver] that emits `screen_view` and `screen_render` on
/// navigation.
///
/// Observation only — it never alters navigation. Added to the app's
/// `navigatorObservers`; on push/replace it reports the **named route**
/// (`route.settings.name`, e.g. `/inbox_screen`) as the `screen` property,
/// which is the app's fixed set of route names (never free-text). Unnamed or
/// anonymous routes are skipped.
///
/// `screen_render` measures **time-to-interactive**: from the navigation to the
/// first frame painted afterwards (via a post-frame callback). [currentScreen]
/// exposes the latest named route so a sibling reporter (frame-jank) can tag its
/// windows. Tracking is fire-and-forget.
class AnalyticsRouteObserver extends NavigatorObserver {
  /// Creates the observer that reports through [_analytics].
  ///
  /// [schedulePostFrame] schedules the post-navigation frame callback used to
  /// time `screen_render`; it defaults to the real binding and is injectable so
  /// tests can drive the timing deterministically.
  AnalyticsRouteObserver(
    this._analytics, {
    void Function(FrameCallback)? schedulePostFrame,
  }) : _schedulePostFrame = schedulePostFrame ?? _defaultSchedule;

  final AnalyticsService _analytics;
  final void Function(FrameCallback) _schedulePostFrame;

  /// The most recently reported named route, or null before the first push.
  String? _currentScreen;

  /// The most recently navigated-to named route (for sibling perf reporters).
  String? get currentScreen => _currentScreen;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreen(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _trackScreen(newRoute, oldRoute);
  }

  /// Emits `screen_view` for [route] and starts a `screen_render` timer;
  /// no-op for an unnamed route.
  void _trackScreen(Route<dynamic> route, Route<dynamic>? previous) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;

    _currentScreen = name;
    final previousName = previous?.settings.name;
    try {
      _analytics.track(Events.screenView, {
        Props.screen: name,
        if (previousName != null && previousName.isNotEmpty)
          Props.previousScreen: previousName,
      });
    } catch (_) {
      // Fire-and-forget — never disrupt navigation.
    }

    _trackRender(name);
  }

  /// Times route push → first painted frame and emits `screen_render`.
  void _trackRender(String name) {
    final stopwatch = Stopwatch()..start();
    _schedulePostFrame((_) {
      stopwatch.stop();
      try {
        _analytics.track(Events.screenRender, {
          Props.screen: name,
          Props.screenRenderMs: stopwatch.elapsedMilliseconds,
        });
      } catch (_) {
        // Fire-and-forget.
      }
    });
  }

  /// Default post-frame scheduler: the real binding when one exists, else a
  /// no-op (e.g. a pure unit test with no binding) so render timing is simply
  /// skipped rather than throwing.
  static void _defaultSchedule(FrameCallback cb) {
    try {
      WidgetsBinding.instance.addPostFrameCallback(cb);
    } catch (_) {
      // No binding available — skip render timing.
    }
  }
}
