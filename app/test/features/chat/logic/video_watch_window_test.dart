// Locks the fix for the "all videos freeze after ~1 minute" bug.
//
// The bug: the reaction watch-window listener was added to the SHARED cached
// video controller but only removed when the video ended/paused — so disposing
// the bubble mid-play orphaned the listener, its closure pinned the dead widget
// in memory, and over a minute of viewing reactions that starved iOS video
// decode until every video froze. The load-bearing invariant is therefore
// "VideoWatchWindow ALWAYS detaches its listener on dispose, even mid-play".
//
// VideoPlayerController is a ValueNotifier<VideoPlayerValue>, so we drive the
// logic with a plain notifier — no video platform channel required.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/logic/video_watch_window.dart';
import 'package:video_player/video_player.dart';

/// A stand-in for the shared controller that exposes whether any listener is
/// attached, so tests can prove the window detaches (no leak).
class _FakeController extends ValueNotifier<VideoPlayerValue> {
  _FakeController() : super(const VideoPlayerValue(duration: Duration.zero));

  /// Exposes the protected [ChangeNotifier.hasListeners] for assertions.
  bool get hasAnyListener => hasListeners;
}

VideoPlayerValue _value({
  Duration duration = const Duration(seconds: 10),
  Duration position = Duration.zero,
  bool isPlaying = false,
  bool isBuffering = false,
}) {
  return VideoPlayerValue(
    duration: duration,
    position: position,
    isInitialized: true,
    isPlaying: isPlaying,
    isBuffering: isBuffering,
  );
}

void main() {
  test('attaches a listener to the controller while watching', () {
    final c = _FakeController();
    VideoWatchWindow(c);
    expect(c.hasAnyListener, isTrue);
  });

  test('completes and detaches when the video reaches its end', () async {
    final c = _FakeController();
    final w = VideoWatchWindow(c);
    c.value = _value(position: const Duration(seconds: 10)); // ended
    await w.ended;
    expect(c.hasAnyListener, isFalse);
  });

  test('completes and detaches when paused after playback started', () async {
    final c = _FakeController();
    final w = VideoWatchWindow(c);
    c.value = _value(position: const Duration(seconds: 3)); // paused mid-play
    await w.ended;
    expect(c.hasAnyListener, isFalse);
  });

  test('does not complete while still playing, and stays attached', () async {
    final c = _FakeController();
    final w = VideoWatchWindow(c);
    var done = false;
    unawaited(w.ended.then((_) => done = true));
    c.value = _value(position: const Duration(seconds: 3), isPlaying: true);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    expect(c.hasAnyListener, isTrue);
  });

  test('does not complete while merely buffering (position 0)', () async {
    final c = _FakeController();
    final w = VideoWatchWindow(c);
    var done = false;
    unawaited(w.ended.then((_) => done = true));
    c.value = _value(isBuffering: true); // buffering, not yet started
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
  });

  // THE REGRESSION GUARD: disposing while the video is still playing must
  // detach the listener. Without the fix the listener stayed attached (leak)
  // and this fails.
  test(
    'dispose mid-play detaches the listener (no leak) and completes',
    () async {
      final c = _FakeController();
      final w = VideoWatchWindow(c);
      c.value = _value(position: const Duration(seconds: 2), isPlaying: true);
      expect(c.hasAnyListener, isTrue);

      w.dispose(); // viewer scrolled away before the video ended
      await w.ended;
      expect(c.hasAnyListener, isFalse);
    },
  );

  test('dispose is idempotent and safe after a natural finish', () async {
    final c = _FakeController();
    final w = VideoWatchWindow(c);
    c.value = _value(position: const Duration(seconds: 10)); // ended
    await w.ended;
    w.dispose();
    w.dispose();
    expect(c.hasAnyListener, isFalse);
  });

  test(
    'null controller completes only when the viewer leaves (dispose)',
    () async {
      final w = VideoWatchWindow(null);
      var done = false;
      unawaited(w.ended.then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(
        done,
        isFalse,
      ); // recorder falls back to its cap until the user leaves
      w.dispose();
      await w.ended;
      expect(done, isTrue);
    },
  );
}
