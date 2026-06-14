import 'package:flutter/widgets.dart';

import 'analytics_service.dart';
import 'events.dart';

/// A [NavigatorObserver] that emits a `screen_view` event on each navigation.
///
/// Observation only — it never alters navigation. Added to the app's
/// `navigatorObservers`; on push/replace it reports the **named route**
/// (`route.settings.name`, e.g. `/inbox_screen`) as the `screen` property,
/// which is the app's fixed set of route names (never free-text). Unnamed or
/// anonymous routes are skipped. Tracking is fire-and-forget.
class AnalyticsRouteObserver extends NavigatorObserver {
  /// Creates the observer that reports screen views through [_analytics].
  AnalyticsRouteObserver(this._analytics);

  final AnalyticsService _analytics;

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

  /// Emits `screen_view` for [route]; no-op for an unnamed route.
  void _trackScreen(Route<dynamic> route, Route<dynamic>? previous) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;

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
  }
}
