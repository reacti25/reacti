// Pins the frame-jank windowing/flush behaviour and the pure jank accumulator.
// frame_jank is emitted per fixed window of frames, only when the window had at
// least one janky frame, tagged with the current screen — observational only.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/analytics/frame_jank_reporter.dart';

import '../support/fake_analytics_service.dart';

void main() {
  group('FrameJankStats', () {
    test('counts frames over the budget and tracks the slowest', () {
      final stats = FrameJankStats(thresholdMs: 16);
      stats.addFrame(8); // smooth
      stats.addFrame(20); // janky
      stats.addFrame(50); // janky + slowest

      expect(stats.frameCount, 3);
      expect(stats.jankCount, 2);
      expect(stats.maxFrameMs, 50);
    });

    test('reset clears all counters', () {
      final stats = FrameJankStats()..addFrame(99);
      stats.reset();
      expect(stats.frameCount, 0);
      expect(stats.jankCount, 0);
      expect(stats.maxFrameMs, 0);
    });
  });

  group('FrameJankReporter', () {
    late FakeAnalyticsService analytics;

    setUp(() => analytics = FakeAnalyticsService());

    test('flushes frame_jank once a full window contains jank', () {
      final reporter = FrameJankReporter(
        analytics,
        currentScreen: () => '/inbox_screen',
        flushEveryFrames: 3,
      );

      reporter.recordFrameMs(8); // smooth
      reporter.recordFrameMs(40); // janky
      expect(analytics.events, isEmpty, reason: 'window not full yet');

      reporter.recordFrameMs(10); // completes the window of 3 -> flush

      final props = analytics.propsOf(Events.frameJank)!;
      expect(props[Props.screen], '/inbox_screen');
      expect(props[Props.jankFrameCount], 1);
      expect(props[Props.jankMaxMs], 40);
      expect(props[Props.frameCount], 3);
    });

    test('a smooth window emits nothing but still resets', () {
      final reporter = FrameJankReporter(analytics, flushEveryFrames: 2);

      reporter.recordFrameMs(5);
      reporter.recordFrameMs(9); // window full, no jank -> no event
      expect(analytics.countOf(Events.frameJank), 0);

      // Next window with jank flushes with only that window's counts (reset).
      reporter.recordFrameMs(33);
      reporter.recordFrameMs(7);
      expect(analytics.propsOf(Events.frameJank)![Props.frameCount], 2);
      expect(analytics.propsOf(Events.frameJank)![Props.jankFrameCount], 1);
    });

    test('omits the screen tag when no current screen is known', () {
      final reporter = FrameJankReporter(analytics, flushEveryFrames: 1);
      reporter.recordFrameMs(40);

      final props = analytics.propsOf(Events.frameJank)!;
      expect(props.containsKey(Props.screen), isFalse);
      expect(props[Props.jankFrameCount], 1);
    });
  });
}
