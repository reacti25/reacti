// Tests for trackMessageSend — the shared send/reaction/media instrumentation
// used by SendMessageRx and SendGroupMessageRx. A FakeAnalyticsService is
// registered in the locator so the `analytics` accessor resolves to it.

import 'dart:typed_data';

import 'package:camera/camera.dart' show XFile;
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/chat_send_analytics.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/helpers/di.dart';

import '../support/fake_analytics_service.dart';

void main() {
  late FakeAnalyticsService analytics;

  setUp(() {
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

  test('a normal text send emits message_sent (text) with send_ms', () {
    trackMessageSend(scope: 'private', ms: 120, success: true);

    final props = analytics.propsOf(Events.messageSent)!;
    expect(props[Props.messageType], 'text');
    expect(props[Props.scope], 'private');
    expect(props[Props.sendMs], 120);
    expect(props[Props.result], 'success');
    expect(analytics.countOf(Events.reactionSent), 0);
  });

  test('a reaction send emits reaction_sent (not message_sent)', () {
    trackMessageSend(scope: 'group', type: 'reaction', ms: 4200, success: true);

    expect(analytics.countOf(Events.messageSent), 0);
    final props = analytics.propsOf(Events.reactionSent)!;
    expect(props[Props.scope], 'group');
    expect(props[Props.uploadMs], 4200);
    expect(props[Props.result], 'success');
  });

  test('a failed send reports result=failure', () {
    trackMessageSend(scope: 'private', ms: 30, success: false);
    expect(analytics.propsOf(Events.messageSent)![Props.result], 'failure');
  });

  test('a media send also emits media_uploaded with a size bucket', () async {
    final bytes = Uint8List.fromList(List<int>.filled(300 * 1024, 0)); // 300KB
    final file = XFile.fromData(
      bytes,
      path: 'clip.jpg',
      mimeType: 'image/jpeg',
    );

    trackMessageSend(scope: 'private', file: file, ms: 80, success: true);
    // media_uploaded is emitted from a detached async size read; let it run.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(analytics.propsOf(Events.messageSent)![Props.messageType], 'media');
    final mu = analytics.propsOf(Events.mediaUploaded)!;
    expect(mu[Props.sizeBucket], 'sm'); // 300 KB → sm
    expect(mu[Props.mediaKind], 'image');
    expect(mu[Props.uploadMs], 80);
    expect(mu[Props.result], 'success');
  });
}
