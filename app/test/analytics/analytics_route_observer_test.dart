// Tests for AnalyticsRouteObserver — emits screen_view on navigation, with the
// named route as the `screen` prop, and skips unnamed routes. Pure-Dart-ish
// widget test using a FakeAnalyticsService (no real navigation needed).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_route_observer.dart';
import 'package:reacti_app/analytics/events.dart';

import '../support/fake_analytics_service.dart';

Route<dynamic> _route(String? name) => MaterialPageRoute<dynamic>(
  settings: RouteSettings(name: name),
  builder: (_) => const SizedBox.shrink(),
);

void main() {
  late FakeAnalyticsService analytics;
  late AnalyticsRouteObserver observer;

  setUp(() {
    analytics = FakeAnalyticsService();
    observer = AnalyticsRouteObserver(analytics);
  });

  test('didPush emits screen_view with screen + previous_screen', () {
    observer.didPush(_route('/inbox_screen'), _route('/navigation_screen'));

    final props = analytics.propsOf(Events.screenView)!;
    expect(props[Props.screen], '/inbox_screen');
    expect(props[Props.previousScreen], '/navigation_screen');
  });

  test('didReplace emits screen_view for the new route', () {
    observer.didReplace(
      newRoute: _route('/login_screen'),
      oldRoute: _route('/signup_screen'),
    );

    expect(analytics.countOf(Events.screenView), 1);
    expect(
      analytics.propsOf(Events.screenView)![Props.screen],
      '/login_screen',
    );
  });

  test('an unnamed route is skipped (no event)', () {
    observer.didPush(_route(null), _route('/inbox_screen'));
    expect(analytics.events, isEmpty);
  });

  test('omits previous_screen when there is no named previous route', () {
    observer.didPush(_route('/navigation_screen'), null);

    final props = analytics.propsOf(Events.screenView)!;
    expect(props[Props.screen], '/navigation_screen');
    expect(props.containsKey(Props.previousScreen), isFalse);
  });
}
