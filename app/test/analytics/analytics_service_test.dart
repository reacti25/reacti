// The privacy-guard tests: AnalyticsService must drop anything not allowlisted,
// must never emit a raw user id, and must attach globals. These FAIL THE BUILD
// if a disallowed property could be emitted — the non-negotiable guarantee from
// docs/PLAN-analytics-stats-2026-06-14.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/events.dart';

import '../support/fake_analytics_service.dart';

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
  });

  group('hashed identity', () {
    test('emits a hashed distinct_id, never the raw id', () {
      analytics.identify('42');
      analytics.track(Events.appOpen);

      final props = analytics.propsOf(Events.appOpen)!;
      final distinctId = props[Props.distinctId] as String;
      expect(distinctId, isNotEmpty);
      expect(distinctId, isNot('42'));
      expect(distinctId.length, 64); // hex SHA-256
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
