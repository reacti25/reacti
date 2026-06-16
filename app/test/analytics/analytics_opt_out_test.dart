// Tests the analytics opt-out gate: when opted out, the AnalyticsService emits
// NOTHING (no track, no identify) — the privacy guarantee behind the Phase 4
// opt-out toggle. Also pins AnalyticsConsent's persistence.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:reacti_app/analytics/analytics_consent.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';

import '../support/fake_analytics_service.dart';
import '../support/test_storage.dart';

void main() {
  group('opt-out gate on AnalyticsService', () {
    test('emits nothing while opted out', () {
      final analytics = FakeAnalyticsService(
        hashSalt: 'salt',
        isOptedOut: () => true,
      );

      analytics.identify('42');
      analytics.track(Events.appOpen, {Props.coldStartMs: 100});
      analytics.track(Events.messageSent, {
        Props.messageType: 'text',
        Props.scope: 'private',
      });

      expect(analytics.events, isEmpty);
    });

    test('emits normally when opted in (default)', () {
      final analytics = FakeAnalyticsService(hashSalt: 'salt');
      analytics.identify('42');
      analytics.track(Events.appOpen);
      expect(analytics.countOf(Events.appOpen), 1);
      expect(
        analytics.propsOf(Events.appOpen)!.containsKey(Props.distinctId),
        isTrue,
      );
    });

    test('a live opt-out flag stops events mid-session', () {
      var optedOut = false;
      final analytics = FakeAnalyticsService(isOptedOut: () => optedOut);

      analytics.track(Events.appOpen);
      optedOut = true; // user flips the toggle
      analytics.track(Events.screenView, {Props.screen: 'inbox'});

      expect(analytics.countOf(Events.appOpen), 1);
      expect(analytics.countOf(Events.screenView), 0);
    });
  });

  group('AnalyticsConsent persistence', () {
    late GetStorage storage;

    setUp(() async {
      await initTestGetStorage();
      storage = locator.get<GetStorage>();
      await storage.remove(kKeyAnalyticsOptOut);
    });

    test('defaults to opted in (not opted out)', () {
      expect(AnalyticsConsent(storage: storage).isOptedOut, isFalse);
    });

    test('setOptedOut persists the flag both ways', () async {
      final consent = AnalyticsConsent(
        storage: storage,
        syncToBackend: (_) async {},
      );
      await consent.setOptedOut(true);
      expect(consent.isOptedOut, isTrue);
      expect(storage.read(kKeyAnalyticsOptOut), isTrue);

      await consent.setOptedOut(false);
      expect(consent.isOptedOut, isFalse);
    });

    test('setOptedOut propagates the preference to the backend', () async {
      final synced = <bool>[];
      final consent = AnalyticsConsent(
        storage: storage,
        syncToBackend: (optedOut) async => synced.add(optedOut),
      );

      await consent.setOptedOut(true);
      await consent.setOptedOut(false);

      // Backend told of both transitions, in order — so the server honours the
      // opt-out durably (no event carrying this user's id while opted out).
      expect(synced, [true, false]);
    });
  });
}
