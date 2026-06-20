// Tests for trackMediaReceivedSealState — the shared seal-integrity signal
// emitted from the chat list sites. A FakeAnalyticsService is registered in the
// locator so the `analytics` accessor resolves to it.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/analytics/media_seal_analytics.dart';
import 'package:reacti_app/helpers/di.dart';

import '../support/fake_analytics_service.dart';

void main() {
  late FakeAnalyticsService analytics;

  void registerAnalytics(FakeAnalyticsService service) {
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(service);
  }

  setUp(() {
    resetMediaSealStateDedupForTest();
    analytics = FakeAnalyticsService();
    registerAnalytics(analytics);
  });

  tearDown(() {
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
  });

  test('a sealed received image emits seal_state=sealed once', () {
    trackMediaReceivedSealState(
      messageId: 1,
      mediaType: 'image',
      messageType: 'normal',
      sealed: true,
      scope: 'private',
      file: 'https://x/img.jpg',
    );

    expect(analytics.countOf(Events.mediaReceivedSealState), 1);
    final props = analytics.propsOf(Events.mediaReceivedSealState)!;
    expect(props[Props.sealState], 'sealed');
    expect(props[Props.mediaKind], 'image');
    expect(props[Props.scope], 'private');
    expect(props[Props.mediaTypeRaw], 'image');
  });

  test('the same message id is reported only once across rebuilds', () {
    for (var i = 0; i < 5; i++) {
      trackMediaReceivedSealState(
        messageId: 42,
        mediaType: 'video',
        messageType: 'normal',
        sealed: true,
        scope: 'group',
        file: 'https://x/clip.mp4',
      );
    }

    expect(analytics.countOf(Events.mediaReceivedSealState), 1);
  });

  test(
    'media with an unexpected media_type is reported open with the raw value',
    () {
      // is_blurred is true, but the type is not one the bubble seals on, so it
      // renders OPEN — the Branch C failure mode. media_type_raw captures it.
      trackMediaReceivedSealState(
        messageId: 2,
        mediaType: 'image/jpeg',
        messageType: 'normal',
        sealed: true,
        scope: 'private',
        file: 'https://x/img.jpg',
      );

      final props = analytics.propsOf(Events.mediaReceivedSealState)!;
      expect(props[Props.sealState], 'open');
      expect(props[Props.mediaTypeRaw], 'image/jpeg');
    },
  );

  test('a null media_type is surfaced as the (null) sentinel', () {
    trackMediaReceivedSealState(
      messageId: 3,
      mediaType: null,
      messageType: 'normal',
      sealed: true,
      scope: 'private',
      file: 'https://x/file.bin',
    );

    final props = analytics.propsOf(Events.mediaReceivedSealState)!;
    expect(props[Props.sealState], 'open');
    expect(props[Props.mediaTypeRaw], '(null)');
  });

  test('a text message (no file) emits nothing', () {
    trackMediaReceivedSealState(
      messageId: 4,
      mediaType: null,
      messageType: 'normal',
      sealed: false,
      scope: 'private',
      file: '',
    );

    expect(analytics.countOf(Events.mediaReceivedSealState), 0);
  });

  test('opt-out suppresses the event entirely', () {
    registerAnalytics(FakeAnalyticsService(isOptedOut: () => true));

    trackMediaReceivedSealState(
      messageId: 5,
      mediaType: 'image',
      messageType: 'normal',
      sealed: true,
      scope: 'private',
      file: 'https://x/img.jpg',
    );

    // The opted-out fake is the one registered; assert against it.
    final optedOut = locator<AnalyticsService>() as FakeAnalyticsService;
    expect(optedOut.countOf(Events.mediaReceivedSealState), 0);
  });
}
