import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Invokes [onStart] each time [_controller] transitions from not-playing to
/// playing — i.e. the moment playback actually begins.
///
/// A [VideoPlayerController] notifies on every position tick (~30–60×/s) while
/// playing, so reacting to "is it playing?" on every notification does the
/// same work dozens of times a second. This collapses that to the single
/// false→true edge, which is all the "only one video plays at a time" and
/// reaction-watched signals need. It also owns its listener and detaches on
/// [dispose] so it can't leak onto the shared cached controller (the class of
/// bug behind the video freeze — see [VideoWatchWindow]).
///
/// Typed against [ValueListenable] so it's unit-testable without the video
/// platform ([VideoPlayerController] is a `ValueNotifier<VideoPlayerValue>`).
class PlaybackStartDetector {
  /// Starts watching [_controller]; a null controller simply never fires.
  PlaybackStartDetector(this._controller, this.onStart) {
    _controller?.addListener(_onChange);
  }

  /// The shared video controller, or null if none was ready.
  final ValueListenable<VideoPlayerValue>? _controller;

  /// Called once each time playback transitions from stopped to playing.
  final VoidCallback onStart;

  /// Last observed playing state, to detect the false→true edge.
  bool _wasPlaying = false;

  /// Whether the listener has been detached, so [dispose] is idempotent.
  bool _detached = false;

  void _onChange() {
    final v = _controller!.value;
    if (!v.isInitialized) return;
    final isPlaying = v.isPlaying;
    if (isPlaying && !_wasPlaying) onStart();
    _wasPlaying = isPlaying;
  }

  /// Detaches from the controller. Safe to call more than once.
  void dispose() {
    if (_detached) return;
    _detached = true;
    _controller?.removeListener(_onChange);
  }
}
