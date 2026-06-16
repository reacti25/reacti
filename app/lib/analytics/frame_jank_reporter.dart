import 'package:flutter/scheduler.dart';

import 'analytics_service.dart';
import 'events.dart';

/// Pure accumulator for frame-jank statistics over a window of frames.
///
/// Fed one frame duration (ms) at a time; counts how many exceeded the budget
/// ([thresholdMs]) and tracks the slowest. No I/O or clock — deterministically
/// unit-testable. A frame is "janky" when its total build+raster span exceeds
/// one 60 fps budget (~16 ms by default).
class FrameJankStats {
  /// Creates an empty accumulator with the given jank [thresholdMs].
  FrameJankStats({this.thresholdMs = 16});

  /// A frame slower than this (ms) counts as janky.
  final int thresholdMs;

  int _frameCount = 0;
  int _jankCount = 0;
  int _maxFrameMs = 0;

  /// Total frames recorded since the last [reset].
  int get frameCount => _frameCount;

  /// Janky frames (over [thresholdMs]) since the last [reset].
  int get jankCount => _jankCount;

  /// Slowest single frame (ms) since the last [reset].
  int get maxFrameMs => _maxFrameMs;

  /// Records one frame's total span in milliseconds.
  void addFrame(int frameMs) {
    _frameCount++;
    if (frameMs > _maxFrameMs) _maxFrameMs = frameMs;
    if (frameMs > thresholdMs) _jankCount++;
  }

  /// Clears all counters for the next window.
  void reset() {
    _frameCount = 0;
    _jankCount = 0;
    _maxFrameMs = 0;
  }
}

/// Reports `frame_jank` over fixed-size windows of frames.
///
/// Hooks the scheduler's frame-timing callback, aggregates via [FrameJankStats],
/// and flushes a `frame_jank` event every [flushEveryFrames] frames — but only
/// when the window contained at least one janky frame, so smooth periods emit
/// nothing. Each event is tagged with the [currentScreen] at flush time.
/// Observation only and fire-and-forget; it never affects rendering.
class FrameJankReporter {
  /// Creates the reporter.
  ///
  /// [currentScreen] supplies the route name to tag windows with (typically
  /// `AnalyticsRouteObserver.currentScreen`). [stats] and [flushEveryFrames]
  /// are injectable for tests.
  FrameJankReporter(
    this._analytics, {
    String? Function()? currentScreen,
    FrameJankStats? stats,
    this.flushEveryFrames = 240,
  }) : _currentScreen = currentScreen ?? (() => null),
       _stats = stats ?? FrameJankStats();

  final AnalyticsService _analytics;
  final String? Function() _currentScreen;
  final FrameJankStats _stats;

  /// Window size in frames before a flush is considered.
  final int flushEveryFrames;

  /// Registers the timing callback with the scheduler binding. No-op (and never
  /// throws) when no binding is available.
  void start() {
    try {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    } catch (_) {
      // No binding — skip jank reporting.
    }
  }

  /// Scheduler callback: convert each [FrameTiming] to ms and record it.
  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      recordFrameMs((timing.totalSpan.inMicroseconds / 1000).round());
    }
  }

  /// Records one frame (ms) and flushes when the window is full. Public so the
  /// windowing/flush behaviour is testable without synthesising [FrameTiming]s.
  void recordFrameMs(int frameMs) {
    _stats.addFrame(frameMs);
    if (_stats.frameCount >= flushEveryFrames) flush();
  }

  /// Emits `frame_jank` for the current window if it had any jank, then resets.
  void flush() {
    if (_stats.frameCount == 0) return;
    if (_stats.jankCount > 0) {
      final screen = _currentScreen();
      try {
        _analytics.track(Events.frameJank, {
          if (screen != null && screen.isNotEmpty) Props.screen: screen,
          Props.jankFrameCount: _stats.jankCount,
          Props.jankMaxMs: _stats.maxFrameMs,
          Props.frameCount: _stats.frameCount,
        });
      } catch (_) {
        // Fire-and-forget.
      }
    }
    _stats.reset();
  }
}
