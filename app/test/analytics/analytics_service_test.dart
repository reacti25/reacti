// The privacy-guard tests: AnalyticsService must drop anything not allowlisted,
// must never emit a raw user id, and must attach globals. These FAIL THE BUILD
// if a disallowed property could be emitted — the non-negotiable guarantee from
// docs/PLAN-analytics-stats-2026-06-14.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_identity.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';

import '../support/fake_analytics_service.dart';

/// Fixed timestamp for contexts whose time value is irrelevant to the assertion.
String _epoch() => '1970-01-01T00:00:00.000Z';

void main() {
  late FakeAnalyticsService analytics;

  setUp(() => analytics = FakeAnalyticsService(hashSalt: 'test-salt'));

  group('allowlist enforcement', () {
    test('drops a property that is not in the event allowlist', () {
      analytics.track(Events.messageSent, {
        Props.messageType: 'text',
        Props.scope: 'private',
        // Disallowed — must never reach dispatch:
        'message_text': 'hello world',
        'recipient_email': 'a@b.com',
      });

      final props = analytics.propsOf(Events.messageSent)!;
      expect(props.containsKey('message_text'), isFalse);
      expect(props.containsKey('recipient_email'), isFalse);
      expect(props[Props.messageType], 'text');
      expect(props[Props.scope], 'private');
    });

    test('drops an entirely unknown event (no ad-hoc names)', () {
      analytics.track('totally_made_up_event', {Props.scope: 'group'});
      expect(analytics.events, isEmpty);
    });

    test('drops null-valued properties', () {
      analytics.track(Events.mediaUploaded, {
        Props.uploadMs: 1200,
        Props.sizeBucket: null,
      });
      final props = analytics.propsOf(Events.mediaUploaded)!;
      expect(props[Props.uploadMs], 1200);
      expect(props.containsKey(Props.sizeBucket), isFalse);
    });

    test('an event with no feature props still emits globals only', () {
      analytics.track(Events.friendAdded);
      final props = analytics.propsOf(Events.friendAdded)!;
      expect(props[Props.analyticsEnv], 'staging');
      expect(props[Props.platform], 'ios');
    });
  });

  group('global properties', () {
    test('every event carries env, platform, session and timestamp', () {
      analytics.track(Events.appOpen, {Props.coldStartMs: 800});
      final props = analytics.propsOf(Events.appOpen)!;
      expect(props[Props.analyticsEnv], 'staging');
      expect(props[Props.platform], 'ios');
      expect(props[Props.sessionId], 'test-session');
      expect(props[Props.ts], '2026-06-15T00:00:00.000Z');
      expect(props[Props.coldStartMs], 800);
    });

    test('carries the app version/build so metrics break down by release', () {
      // kTestAnalyticsContext sets appVersion 1.1.0 / build 11.
      analytics.track(Events.appOpen);
      final props = analytics.propsOf(Events.appOpen)!;
      expect(props[Props.appVersion], '1.1.0');
      expect(props[Props.appBuild], '11');
    });

    test('omits app version/build when they were never captured', () {
      // An empty version must be omitted, not emitted as a blank string.
      final noVersion = FakeAnalyticsService(
        context: const AnalyticsContext(
          env: 'staging',
          platform: 'ios',
          appVersion: '',
          appBuild: '',
          sessionId: 's',
          nowIso: _epoch,
        ),
      );
      noVersion.track(Events.appOpen);
      final props = noVersion.propsOf(Events.appOpen)!;
      expect(props.containsKey(Props.appVersion), isFalse);
      expect(props.containsKey(Props.appBuild), isFalse);
    });
  });

  group('hashed identity', () {
    test('emits the SALTED hash as distinct_id, never the raw id', () {
      analytics.identify('42'); // service was built with hashSalt: 'test-salt'
      analytics.track(Events.appOpen);

      final distinctId =
          analytics.propsOf(Events.appOpen)![Props.distinctId] as String;
      expect(distinctId, isNot('42'));
      expect(distinctId, AnalyticsIdentity.hashUserId('42', salt: 'test-salt'));
      // And it is NOT the brute-forceable plain hash of the id.
      expect(distinctId, isNot(AnalyticsIdentity.hashUserId('42', salt: '')));
    });

    test('emits NO distinct_id when no salt is configured (anonymous)', () {
      // A service with an empty salt must never emit a reversible id — it stays
      // anonymous rather than falling back to an unsalted hash.
      final unsalted = FakeAnalyticsService();
      unsalted.identify('42');
      unsalted.track(Events.appOpen);

      expect(
        unsalted.propsOf(Events.appOpen)!.containsKey(Props.distinctId),
        isFalse,
      );
    });

    test('no distinct_id before identify, and cleared on reset', () {
      analytics.track(Events.appOpen);
      expect(
        analytics.propsOf(Events.appOpen)!.containsKey(Props.distinctId),
        isFalse,
      );

      analytics.identify('42');
      analytics.reset();
      analytics.track(Events.screenView, {Props.screen: 'inbox'});
      expect(
        analytics.propsOf(Events.screenView)!.containsKey(Props.distinctId),
        isFalse,
      );
    });
  });
}
