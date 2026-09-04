// Tests for permission_result — the event that separates "was refused" from
// "was not interested". A FakeAnalyticsService is registered in the locator so
// the `analytics` accessor resolves to it.

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/analytics/permission_analytics.dart';
import 'package:reacti_app/helpers/di.dart';

import '../support/fake_analytics_service.dart';
import '../support/test_storage.dart';

void main() {
  late FakeAnalyticsService analytics;

  setUp(() async {
    await initTestGetStorage();
    // The last-reported answer is persisted, and GetStorage's container is
    // shared across the tests in this file, so clear it or one test's answer
    // suppresses the next test's identical one.
    for (final permission in [
      Permissions.camera,
      Permissions.microphone,
      Permissions.notifications,
      Permissions.contacts,
    ]) {
      await appData.remove('$kKeyPermissionReported:$permission');
    }
    analytics = FakeAnalyticsService();
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() {
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
  });

  test('a granted camera answer is reported with the permission name', () {
    trackPermissionStatus(Permissions.camera, PermissionStatus.granted);

    final props = analytics.propsOf(Events.permissionResult)!;
    expect(props[Props.permission], 'camera');
    expect(props[Props.result], 'granted');
  });

  test('a denial is reported, not silently dropped', () {
    // The whole point: a refusal has to be visible, because the person it
    // happened to looks like a disinterested user in every other number.
    trackPermissionStatus(Permissions.camera, PermissionStatus.denied);

    expect(analytics.propsOf(Events.permissionResult)![Props.result], 'denied');
  });

  test('a permanent denial stays distinct from an ordinary one', () {
    // Different problem, different fix: one can be re-asked, the other only
    // resolves in Settings.
    trackPermissionStatus(
      Permissions.contacts,
      PermissionStatus.permanentlyDenied,
    );

    expect(
      analytics.propsOf(Events.permissionResult)![Props.result],
      'permanently_denied',
    );
  });

  test('a partial grant is not counted as a full one', () {
    expect(permissionResultOf(PermissionStatus.limited), 'limited');
    expect(permissionResultOf(PermissionStatus.provisional), 'provisional');
  });

  test('a missing status reads as unknown rather than a guess', () {
    expect(permissionResultOf(null), 'unknown');
  });

  test('a change of mind is emitted', () {
    trackPermissionResult(Permissions.notifications, 'denied');
    trackPermissionResult(Permissions.notifications, 'granted');

    // Two events: reading a current state means taking the latest, so the
    // second answer has to be there to be found.
    expect(analytics.countOf(Events.permissionResult), 2);
  });

  test('an unchanged answer is not re-emitted', () {
    // Push permission is re-requested on every launch and returns the standing
    // answer without showing a dialog. Reporting each one would make this the
    // app's chattiest event and say nothing new.
    trackPermissionResult(Permissions.notifications, 'granted');
    trackPermissionResult(Permissions.notifications, 'granted');
    trackPermissionResult(Permissions.notifications, 'granted');

    expect(analytics.countOf(Events.permissionResult), 1);
  });

  test('one permission does not suppress another', () {
    trackPermissionResult(Permissions.camera, 'granted');
    trackPermissionResult(Permissions.microphone, 'granted');

    expect(analytics.countOf(Events.permissionResult), 2);
  });

  test('nothing but the permission, result and elapsed time is emitted', () {
    trackPermissionStatus(Permissions.microphone, PermissionStatus.granted);

    final props = analytics.propsOf(Events.permissionResult)!;
    expect(
      props.keys.toSet().difference({
        Props.permission,
        Props.result,
        Props.msSinceFirstLaunch,
        ...Props.globals,
      }),
      isEmpty,
    );
  });
}
