// Tests for AnalyticsBootstrap — the default-off wiring and the app_open emit.
//
// In tests no --dart-define keys are set, so analytics is disabled: buildService
// must return the no-op implementation (the "no behaviour change" guarantee).

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
}
