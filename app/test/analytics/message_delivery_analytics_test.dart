// Tests for trackMessageReceived / messageTypeFromRealtime — the recipient-side
// realtime-delivery instrumentation emitted from the Pusher onEvent handlers.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/analytics/message_delivery_analytics.dart';
import 'package:reacti_app/helpers/di.dart';

import '../support/fake_analytics_service.dart';

void main() {
  late FakeAnalyticsService analytics;

  void register(FakeAnalyticsService service) {
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(service);
  }

  setUp(() {
    analytics = FakeAnalyticsService();
    register(analytics);
  });

  tearDown(() {
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
  });

  group('messageTypeFromRealtime', () {
    test('a reaction type wins regardless of file', () {
      expect(
        messageTypeFromRealtime(rawType: 'reaction', file: null),
        'reaction',
      );
    });

    test('a file present (non-reaction) is media', () {
      expect(
        messageTypeFromRealtime(rawType: 'normal', file: 'a.jpg'),
        'media',
      );
    });

    test('no file is text', () {
      expect(messageTypeFromRealtime(rawType: 'normal', file: null), 'text');
    });
  });

  test(
    'trackMessageReceived emits scope + message_type and omits delivery_ms',
    () {
      trackMessageReceived(scope: 'private', messageType: 'media');

      final props = analytics.propsOf(Events.messageReceived)!;
      expect(props[Props.scope], 'private');
      expect(props[Props.messageType], 'media');
      // delivery_ms can't be computed from a relative timestamp — never fabricated.
      expect(props.containsKey(Props.deliveryMs), isFalse);
    },
  );

  test('an opted-out user emits no message_received', () {
    register(FakeAnalyticsService(isOptedOut: () => true));

    trackMessageReceived(scope: 'group', messageType: 'text');

    final service = locator<AnalyticsService>() as FakeAnalyticsService;
    expect(service.countOf(Events.messageReceived), 0);
  });
}
