// Tests for AnalyticsBootstrap — the default-off wiring and the app_open emit.
//
// In tests no --dart-define keys are set, so analytics is disabled: buildService
// must return the no-op implementation (the "no behaviour change" guarantee).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_bootstrap.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/analytics/noop_analytics_service.dart';

import '../support/fake_analytics_service.dart';

void main() {
  test('buildService returns a no-op when analytics is disabled (default)', () {
    expect(AnalyticsBootstrap.buildService(), isA<NoopAnalyticsService>());
  });

  test('trackAppOpen emits app_open with cold_start_ms and is_cold_start', () {
    final analytics = FakeAnalyticsService();
    final sw = Stopwatch()..start();
    sw.stop();

    AnalyticsBootstrap.trackAppOpen(analytics, sw);

    final props = analytics.propsOf(Events.appOpen)!;
    expect(props[Props.coldStartMs], isA<int>());
    expect(props[Props.isColdStart], isTrue);
  });

  test('trackAppOpen carries the start-up step times', () {
    final analytics = FakeAnalyticsService();

    AnalyticsBootstrap.trackAppOpen(
      analytics,
      Stopwatch(),
      steps: {Props.tokenLoadMs: 42},
    );

    expect(analytics.propsOf(Events.appOpen)![Props.tokenLoadMs], 42);
  });

  group('StartupTimings', () {
    test('records how long a step took', () async {
      final timings = StartupTimings();

      await timings.time(Props.storageInitMs, () async {});

      expect(timings.props[Props.storageInitMs], isA<int>());
    });

    test(
      'a failing step is still timed and its error reaches the caller',
      () async {
        final timings = StartupTimings();

        await expectLater(
          timings.time(Props.firebaseInitMs, () async => throw StateError('x')),
          throwsStateError,
        );
        expect(timings.props, contains(Props.firebaseInitMs));
      },
    );
  });

  group('detectTestLab', () {
    const channel = MethodChannel('reacti/test_lab');
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      AnalyticsBootstrap.inTestLab = false;
    });

    test('Google test lab switches analytics off', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      await AnalyticsBootstrap.detectTestLab();
      expect(AnalyticsBootstrap.inTestLab, isTrue);
    });

    test('no channel (iOS) is a real device', () async {
      await AnalyticsBootstrap.detectTestLab();
      expect(AnalyticsBootstrap.inTestLab, isFalse);
    });
  });
}
