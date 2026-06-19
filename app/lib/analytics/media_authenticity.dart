/// The authenticity overlap between the silent-recording window and the
/// media-exposure window, as emitted by `recording_media_overlap`.
///
/// All fields are integer milliseconds except [overlapPct] (0–100). See
/// `docs/analytics/event-catalog.md` for the wire contract.
class MediaOverlap {
  /// Creates an overlap result with already-computed fields.
  const MediaOverlap({
    required this.overlapMs,
    required this.overlapPct,
    required this.recordingStartOffsetMs,
    required this.recordingDurationMs,
    required this.mediaExposureMs,
  });

  /// Milliseconds the recording window overlapped the exposure window.
  final int overlapMs;

  /// [overlapMs] as a percentage of [recordingDurationMs], clamped to 0–100.
  final int overlapPct;

  /// Signed offset of recording start relative to media becoming visible.
  final int recordingStartOffsetMs;

  /// Duration of the recording window.
  final int recordingDurationMs;

  /// Duration the media was exposed (visible → hidden).
  final int mediaExposureMs;
}

/// Pure timing math behind the patent authenticity metric.
///
/// Answers "how much of the silent reaction was captured while the media was
/// actually on screen?" with no I/O or clock access — the widget supplies the
/// measured offsets and this computes the intersection, so the logic is
/// deterministically unit-testable off the load-bearing patent path.
class MediaAuthenticity {
  MediaAuthenticity._();

  /// Computes the overlap of the recording and exposure windows.
  ///
  /// Both windows share an origin at *media becomes visible* (t=0):
  /// - exposure window is `[0, mediaExposureMs]`;
  /// - recording window is `[recordingStartOffsetMs, recordingStartOffsetMs +
  ///   recordingDurationMs]` ([recordingStartOffsetMs] may be negative when the
  ///   camera started before the media was visible).
  ///
  /// [overlapPct] is `round(overlapMs / recordingDurationMs * 100)` clamped to
  /// 0–100 (0 when [recordingDurationMs] is non-positive).
  static MediaOverlap compute({
    required int recordingStartOffsetMs,
    required int recordingDurationMs,
    required int mediaExposureMs,
  }) {
    final recordEnd = recordingStartOffsetMs + recordingDurationMs;
    final overlapStart =
        recordingStartOffsetMs < 0 ? 0 : recordingStartOffsetMs;
    final overlapEnd =
        recordEnd < mediaExposureMs ? recordEnd : mediaExposureMs;
    final overlapMs = overlapEnd > overlapStart ? overlapEnd - overlapStart : 0;
    final overlapPct =
        recordingDurationMs > 0
            ? ((overlapMs / recordingDurationMs) * 100).round().clamp(0, 100)
            : 0;

    return MediaOverlap(
      overlapMs: overlapMs,
      overlapPct: overlapPct,
      recordingStartOffsetMs: recordingStartOffsetMs,
      recordingDurationMs: recordingDurationMs,
      mediaExposureMs: mediaExposureMs,
    );
  }
}
