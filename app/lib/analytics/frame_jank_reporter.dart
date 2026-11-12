import 'package:flutter/scheduler.dart';

import 'analytics_service.dart';
import 'events.dart';

/// One refresh interval of a 60 Hz screen, the budget when none is given.
const Duration sixtyHzBudget = Duration(microseconds: 16667);

/// Pure accumulator for frame-jank statistics over a window of frames.
///
/// Fed one frame at a time. Keeps two views of the same frames:
///
/// * the original one: a frame is "janky" when its total span (vsync start to
///   raster end) is over a fixed [thresholdMs]. Kept unchanged so history stays
///   comparable, but it over-counts: build and raster run on two threads, so a
///   total over one interval does not mean a frame was missed.
/// * the accurate one: a frame is slow when its build time or its raster time
///   alone is over the screen's refresh interval (Flutter's own definition),
///   which also says WHICH half was slow: Dart code or drawing.
///
/// No I/O or clock, so it is deterministically unit-testable.
class FrameJankStats {
  /// Creates an empty accumulator with the given fixed jank [thresholdMs].
  FrameJankStats({this.thresholdMs = 16});

  /// A frame whose total span is over this (ms) counts as janky.
  final int thresholdMs;

  int _frameCount = 0;
  int _jankCount = 0;
  int _maxFrameMs = 0;
  int _slowBuildCount = 0;
  int _slowRasterCount = 0;
  int _maxBuildMs = 0;
  int _maxRasterMs = 0;

  /// Total frames recorded since the last [reset].
  int get frameCount => _frameCount;

  /// Frames whose total span was over [thresholdMs] since the last [reset].
  int get jankCount => _jankCount;

  /// Longest total span of a single frame (ms) since the last [reset].
  int get maxFrameMs => _maxFrameMs;

  /// Frames whose build (Dart code) took longer than the refresh interval.
  int get slowBuildCount => _slowBuildCount;

  /// Frames whose raster (drawing) took longer than the refresh interval.
  int get slowRasterCount => _slowRasterCount;

  /// Longest build of a single frame (ms) since the last [reset].
  int get maxBuildMs => _maxBuildMs;

  /// Longest raster of a single frame (ms) since the last [reset].
  int get maxRasterMs => _maxRasterMs;

  /// Whether the window holds a frame worth reporting under either view.
  bool get hasSlowFrame =>
      _jankCount > 0 || _slowBuildCount > 0 || _slowRasterCount > 0;

  /// Records one frame: its [total] span, its [build] and [raster] halves, and
  /// the [budget] (one refresh interval) the halves are judged against.
  void addFrame({
    required Duration total,
    Duration build = Duration.zero,
    Duration raster = Duration.zero,
    Duration budget = sixtyHzBudget,
  }) {
    _frameCount++;
    final totalMs = _roundedMs(total);
    if (totalMs > _maxFrameMs) _maxFrameMs = totalMs;
    if (totalMs > thresholdMs) _jankCount++;

    if (build > budget) _slowBuildCount++;
    if (raster > budget) _slowRasterCount++;
    final buildMs = _roundedMs(build);
    if (buildMs > _maxBuildMs) _maxBuildMs = buildMs;
    final rasterMs = _roundedMs(raster);
    if (rasterMs > _maxRasterMs) _maxRasterMs = rasterMs;
  }

  /// Clears all counters for the next window.
  void reset() {
    _frameCount = 0;
    _jankCount = 0;
    _maxFrameMs = 0;
    _slowBuildCount = 0;
    _slowRasterCount = 0;
    _maxBuildMs = 0;
    _maxRasterMs = 0;
  }

  /// [duration] in whole milliseconds, rounded to the nearest.
  static int _roundedMs(Duration duration) =>
      (duration.inMicroseconds / 1000).round();
}

/// Reports `frame_jank` over fixed-size windows of frames.
///
/// Hooks the scheduler's frame-timing callback, aggregates via [FrameJankStats],
/// and flushes a `frame_jank` event every [flushEveryFrames] frames — but only
/// when the window contained at least one slow frame, so smooth periods emit
/// nothing. The frames of those silent windows are carried on the next event
/// as `quiet_frame_count`, so a slow-frame percentage has an honest
/// denominator. Each event is tagged with the [currentScreen] at flush time.
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

  /// Refresh rate (Hz) the most recent frame was judged against.
  double _refreshHz = 60;

  /// Frames of the smooth windows that emitted nothing since the last event.
  int _quietFrameCount = 0;

  /// Registers the timing callback with the scheduler binding. No-op (and never
  /// throws) when no binding is available.
  void start() {
    try {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    } catch (_) {
      // No binding — skip jank reporting.
    }
  }

  /// Scheduler callback: record each [FrameTiming] against the refresh rate
  /// the screen runs at right now (it can change, e.g. 60/90/120 Hz phones).
  void _onTimings(List<FrameTiming> timings) {
    final refreshHz = _displayRefreshRate();
    for (final timing in timings) {
      recordFrame(
        total: timing.totalSpan,
        build: timing.buildDuration,
        raster: timing.rasterDuration,
        refreshHz: refreshHz,
      );
    }
  }

  /// Records one frame and flushes when the window is full. Public so the
  /// windowing/flush behaviour is testable without synthesising [FrameTiming]s.
  void recordFrame({
    required Duration total,
    Duration build = Duration.zero,
    Duration raster = Duration.zero,
    double refreshHz = 60,
  }) {
    _refreshHz = refreshHz;
    _stats.addFrame(
      total: total,
      build: build,
      raster: raster,
      budget: Duration(microseconds: (1e6 / refreshHz).round()),
    );
    if (_stats.frameCount >= flushEveryFrames) flush();
  }

  /// Emits `frame_jank` for the current window if it had a slow frame, then
  /// resets. A smooth window emits nothing; its frames are remembered for the
  /// next event's `quiet_frame_count`.
  void flush() {
    if (_stats.frameCount == 0) return;
    if (_stats.hasSlowFrame) {
      final screen = _currentScreen();
      try {
        _analytics.track(Events.frameJank, {
          if (screen != null && screen.isNotEmpty) Props.screen: screen,
          Props.jankFrameCount: _stats.jankCount,
          Props.jankMaxMs: _stats.maxFrameMs,
          Props.frameCount: _stats.frameCount,
          Props.refreshHz: _refreshHz.round(),
          Props.slowBuildCount: _stats.slowBuildCount,
          Props.slowRasterCount: _stats.slowRasterCount,
          Props.buildMaxMs: _stats.maxBuildMs,
          Props.rasterMaxMs: _stats.maxRasterMs,
          Props.quietFrameCount: _quietFrameCount,
        });
      } catch (_) {
        // Fire-and-forget.
      }
      _quietFrameCount = 0;
    } else {
      _quietFrameCount += _stats.frameCount;
    }
    _stats.reset();
  }
}

/// The display's refresh rate in Hz, or 60 when the platform reports none
/// (no view yet, or a rate of zero).
double _displayRefreshRate() {
  try {
    final hz =
        SchedulerBinding
            .instance
            .platformDispatcher
            .views
            .first
            .display
            .refreshRate;
    return hz > 0 ? hz : 60;
  } catch (_) {
    return 60;
  }
}
