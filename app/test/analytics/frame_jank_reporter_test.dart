// Pins the frame-jank windowing/flush behaviour and the pure jank accumulator.
// frame_jank is emitted per fixed window of frames, only when the window had at
// least one slow frame, tagged with the current screen — observational only.
// A frame is judged two ways: its total span against a fixed 16 ms (the
// original count, kept for history) and its build and raster halves against
// the screen's refresh interval (the accurate count).

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/analytics/frame_jank_reporter.dart';

import '../support/fake_analytics_service.dart';

/// Shorthand: a [Duration] of [value] milliseconds.
Duration ms(int value) => Duration(milliseconds: value);

void main() {
  group('FrameJankStats', () {
    test('counts frames over the fixed budget and tracks the slowest', () {
      final stats = FrameJankStats(thresholdMs: 16);
      stats.addFrame(total: ms(8)); // smooth
      stats.addFrame(total: ms(20)); // janky
      stats.addFrame(total: ms(50)); // janky + slowest

      expect(stats.frameCount, 3);
      expect(stats.jankCount, 2);
      expect(stats.maxFrameMs, 50);
    });

    test('counts slow builds and slow rasters separately', () {
      final stats = FrameJankStats();
      stats.addFrame(total: ms(30), build: ms(25), raster: ms(5));
      stats.addFrame(total: ms(40), build: ms(4), raster: ms(36));
      stats.addFrame(total: ms(12), build: ms(6), raster: ms(6));

      expect(stats.slowBuildCount, 1);
      expect(stats.slowRasterCount, 1);
      expect(stats.maxBuildMs, 25);
      expect(stats.maxRasterMs, 36);
    });

    test('a total over 16 ms is not a slow frame when each half fits', () {
      // Build and raster run on two threads: 12 ms each is a 24 ms span but
      // both halves finish inside one 60 Hz interval, so no frame is missed.
      final stats = FrameJankStats();
      stats.addFrame(total: ms(24), build: ms(12), raster: ms(12));

      expect(stats.jankCount, 1, reason: 'the original count still sees it');
      expect(stats.slowBuildCount, 0);
      expect(stats.slowRasterCount, 0);
    });

    test('the budget follows the refresh rate', () {
      // 10 ms of build fits a 60 Hz interval (16.7 ms), not a 120 Hz one (8.3).
      final at60 = FrameJankStats()..addFrame(total: ms(10), build: ms(10));
      final at120 =
          FrameJankStats()..addFrame(
            total: ms(10),
            build: ms(10),
            budget: const Duration(microseconds: 8333),
          );

      expect(at60.slowBuildCount, 0);
      expect(at60.hasSlowFrame, isFalse);
      expect(at120.slowBuildCount, 1);
      expect(at120.hasSlowFrame, isTrue);
    });

    test('reset clears all counters', () {
      final stats =
          FrameJankStats()
            ..addFrame(total: ms(99), build: ms(60), raster: ms(39));
      stats.reset();
      expect(stats.frameCount, 0);
      expect(stats.jankCount, 0);
      expect(stats.maxFrameMs, 0);
      expect(stats.slowBuildCount, 0);
      expect(stats.slowRasterCount, 0);
      expect(stats.maxBuildMs, 0);
      expect(stats.maxRasterMs, 0);
      expect(stats.hasSlowFrame, isFalse);
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

      reporter.recordFrame(total: ms(8)); // smooth
      reporter.recordFrame(total: ms(40), build: ms(30), raster: ms(10));
      expect(analytics.events, isEmpty, reason: 'window not full yet');

      reporter.recordFrame(total: ms(10)); // completes the window -> flush

      final props = analytics.propsOf(Events.frameJank)!;
      expect(props[Props.screen], '/inbox_screen');
      expect(props[Props.jankFrameCount], 1);
      expect(props[Props.jankMaxMs], 40);
      expect(props[Props.frameCount], 3);
      expect(props[Props.refreshHz], 60);
      expect(props[Props.slowBuildCount], 1);
      expect(props[Props.slowRasterCount], 0);
      expect(props[Props.buildMaxMs], 30);
      expect(props[Props.rasterMaxMs], 10);
      expect(props[Props.quietFrameCount], 0);
    });

    test('a smooth window emits nothing but still resets', () {
      final reporter = FrameJankReporter(analytics, flushEveryFrames: 2);

      reporter.recordFrame(total: ms(5));
      reporter.recordFrame(total: ms(9)); // window full, no jank -> no event
      expect(analytics.countOf(Events.frameJank), 0);

      // Next window with jank flushes with only that window's counts (reset).
      reporter.recordFrame(total: ms(33));
      reporter.recordFrame(total: ms(7));
      expect(analytics.propsOf(Events.frameJank)![Props.frameCount], 2);
      expect(analytics.propsOf(Events.frameJank)![Props.jankFrameCount], 1);
    });

    test('the frames of smooth windows ride on the next event, once', () {
      final reporter = FrameJankReporter(analytics, flushEveryFrames: 2);

      // Two smooth windows (4 frames) emit nothing.
      for (var i = 0; i < 4; i++) {
        reporter.recordFrame(total: ms(5));
      }
      reporter.recordFrame(total: ms(33));
      reporter.recordFrame(total: ms(7));
      expect(analytics.propsOf(Events.frameJank)![Props.quietFrameCount], 4);

      // The next slow window starts counting quiet frames from zero again.
      reporter.recordFrame(total: ms(33));
      reporter.recordFrame(total: ms(7));
      expect(analytics.countOf(Events.frameJank), 2);
      expect(analytics.last!.props[Props.quietFrameCount], 0);
    });

    test('on a 120 Hz screen a build over 8.3 ms is reported', () {
      final reporter = FrameJankReporter(analytics, flushEveryFrames: 1);

      // Under the fixed 16 ms, so the original count alone would stay silent.
      reporter.recordFrame(total: ms(12), build: ms(10), refreshHz: 120);

      final props = analytics.propsOf(Events.frameJank)!;
      expect(props[Props.refreshHz], 120);
      expect(props[Props.jankFrameCount], 0);
      expect(props[Props.slowBuildCount], 1);
    });

    test('omits the screen tag when no current screen is known', () {
      final reporter = FrameJankReporter(analytics, flushEveryFrames: 1);
      reporter.recordFrame(total: ms(40));

      final props = analytics.propsOf(Events.frameJank)!;
      expect(props.containsKey(Props.screen), isFalse);
      expect(props[Props.jankFrameCount], 1);
    });
  });
}
