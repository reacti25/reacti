/// Per-segment timings of the tap → mark-viewed → media-ready → painted →
/// record-start sequence, all anchored at the tap (t=0).
///
/// This is the "before" baseline for the trigger-on-paint work (Phase 1 of
/// `docs/PLAN-media-timing-and-speed-2026-06-23.md`): it makes each segment of
/// the patent-flow open measurable so re-anchoring the silent recording to the
/// first painted frame can be proven on a dashboard.
///
/// Pure value object with no I/O or clock access — the widget supplies the
/// captured [DateTime]s and this computes the offsets, so it is deterministically
/// unit-testable off the load-bearing patent path (mirrors [MediaAuthenticity]).
class MediaTimeline {
  /// Creates a timeline from already-computed millisecond offsets.
  ///
  /// Every field is null when its segment never occurred (e.g. the media never
  /// painted, or the recording never started).
  const MediaTimeline({
    required this.markViewedMs,
    required this.mediaReadyMs,
    required this.paintedMs,
    required this.recordStartMs,
  });

  /// Milliseconds from tap to the `mark-viewed` response (unblur).
  final int? markViewedMs;

  /// Milliseconds from tap to the media being ready (image decoded / video
  /// first frame).
  final int? mediaReadyMs;

  /// Milliseconds from tap to the first painted frame after the media was ready.
  final int? paintedMs;

  /// Milliseconds from tap to the silent recording starting.
  final int? recordStartMs;

  /// Computes the segment offsets relative to [tapAt].
  ///
  /// Any segment whose timestamp is null stays null in the result (the segment
  /// did not happen this view); offsets may be negative only if a caller passes
  /// a timestamp earlier than [tapAt], which the widget never does.
  static MediaTimeline fromTimestamps({
    required DateTime tapAt,
    DateTime? markViewedAt,
    DateTime? mediaReadyAt,
    DateTime? paintedAt,
    DateTime? recordStartAt,
  }) {
    int? offset(DateTime? at) => at?.difference(tapAt).inMilliseconds;

    return MediaTimeline(
      markViewedMs: offset(markViewedAt),
      mediaReadyMs: offset(mediaReadyAt),
      paintedMs: offset(paintedAt),
      recordStartMs: offset(recordStartAt),
    );
  }
}
