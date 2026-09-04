// Tests for SessionTracker — the source of session length, which is the
// difference between "they opened the app" and "they used it".

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/analytics/session_tracker.dart';
import 'package:reacti_app/helpers/di.dart';

import '../support/fake_analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAnalyticsService analytics;
  late SessionTracker tracker;

  setUp(() {
    analytics = FakeAnalyticsService();
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(analytics);
    tracker = SessionTracker.start();
  });

  tearDown(() {
    tracker.dispose();
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
  });

  test('starting opens a session', () {
    expect(analytics.countOf(Events.sessionStart), 1);
    expect(analytics.countOf(Events.sessionEnd), 0);
  });

  test('backgrounding closes the session with its length', () {
    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);

    final props = analytics.propsOf(Events.sessionEnd)!;
    expect(props[Props.elapsedMs], isA<int>());
    expect(props[Props.elapsedMs], greaterThanOrEqualTo(0));
  });

  test('inactive is not treated as leaving', () {
    // `inactive` fires while the app is still on screen — a system dialog, the
    // app switcher, a permission prompt. Ending a session there would chop one
    // real session into several short ones and drag the median down.
    tracker.didChangeAppLifecycleState(AppLifecycleState.inactive);

    expect(analytics.countOf(Events.sessionEnd), 0);
  });

  test('coming back opens a new session', () {
    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
    tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(analytics.countOf(Events.sessionStart), 2);
    expect(analytics.countOf(Events.sessionEnd), 1);
  });

  test('a repeated pause does not close the same session twice', () {
    // Two session_ends for one session would halve the median session length.
    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);

    expect(analytics.countOf(Events.sessionEnd), 1);
  });

  test('a resume without a preceding pause does not double-open', () {
    tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(analytics.countOf(Events.sessionStart), 1);
  });
}
