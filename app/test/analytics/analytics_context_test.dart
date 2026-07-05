// Tests for AnalyticsContext.captureAppInfo → runtime() wiring: the app
// version/build read at bootstrap must flow onto the runtime context so every
// event carries the running release.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';

void main() {
  // The captured version is a static; reset it so tests don't leak into each
  // other or into other suites.
  tearDown(() => AnalyticsContext.captureAppInfo(version: '', build: ''));

  test('runtime() attaches the version/build captured at bootstrap', () {
    AnalyticsContext.captureAppInfo(version: '1.3.1', build: '15');

    final ctx = AnalyticsContext.runtime();

    expect(ctx.appVersion, '1.3.1');
    expect(ctx.appBuild, '15');
  });

  test('runtime() leaves version/build empty when nothing was captured', () {
    final ctx = AnalyticsContext.runtime();

    expect(ctx.appVersion, '');
    expect(ctx.appBuild, '');
  });

  test('captureAppInfo is idempotent — the latest value wins', () {
    AnalyticsContext.captureAppInfo(version: '1.0.0', build: '1');
    AnalyticsContext.captureAppInfo(version: '1.3.1', build: '15');

    expect(AnalyticsContext.runtime().appVersion, '1.3.1');
  });
}
