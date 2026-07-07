import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Signals when the viewer has finished watching a just-opened video, so the
/// silent reaction recording can stop at the real watch length.
///
/// "Finished" means the video reached its end, was paused after playback began,
/// or the viewer left the screen (via [dispose]). [ended] completes once for
/// whichever happens first.
///
/// **Why this is a class of its own:** the watched controller is the SHARED,
/// cached [VideoPlayerController] (one per URL in `VideoControllerCache`), so
/// the listener MUST be detached on [dispose]. Previously it was only removed
/// when the video ended/paused, so disposing the bubble mid-play (scrolling
/// away) orphaned the listener on the shared controller and its closure pinned
/// the dead widget State in memory. Accumulated over a minute of viewing
/// reactions, that starved iOS video decode and froze every video at once (see
/// `docs/ROOT-CAUSE-video-freeze-2026-07-07.md`). Isolating the listener
/// lifecycle here makes "always detaches on dispose" a directly unit-tested
/// invariant — typed against [ValueListenable] so no video platform is needed.
class VideoWatchWindow {
  /// Starts the window watching [_controller]. A null controller (video not
  /// ready) means [ended] completes only when the viewer leaves ([dispose]).
  VideoWatchWindow(this._controller) {
    _controller?.addListener(_onChange);
  }

  /// The shared video controller being watched, or null if none was ready.
  final ValueListenable<VideoPlayerValue>? _controller;

  /// Completes (once) when watching is over. Never throws.
  final Completer<void> _ended = Completer<void>();

  /// Whether the listener has already been detached, so [_finish] is idempotent.
  bool _detached = false;

  /// Completes when the video ends, is paused after playback, or the viewer
  /// leaves. Feeds the recorder's `stopEarly`.
  Future<void> get ended => _ended.future;

  /// Controller-change handler: completes once the video has genuinely ended or
  /// been paused (not merely buffering) after playback started.
  void _onChange() {
    if (_ended.isCompleted) return;
    final v = _controller!.value;
    if (!v.isInitialized) return;
    final reachedEnd = v.duration > Duration.zero && v.position >= v.duration;
    final paused = !v.isPlaying && !v.isBuffering && v.position > Duration.zero;
    if (reachedEnd || paused) _finish();
  }

  /// Ends the window because the viewer left, detaching the listener. Safe to
  /// call more than once and after a natural finish.
  void dispose() => _finish();

  /// Completes [ended] and detaches from the shared controller, exactly once.
  void _finish() {
    if (!_ended.isCompleted) _ended.complete();
    if (!_detached) {
      _detached = true;
      _controller?.removeListener(_onChange);
    }
  }
}
