// Locks the video-playback CPU tidy-up: pause-others / reaction-watched work
// must run only on the false→true "playback started" edge, NOT on every
// position tick (~30–60×/s). Also guards the same detach-on-dispose invariant
// as VideoWatchWindow, so this listener can't leak onto the shared controller.
//
// VideoPlayerController is a ValueNotifier<VideoPlayerValue>, so a plain
// notifier drives the logic with no video platform channel.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/logic/playback_start_detector.dart';
import 'package:video_player/video_player.dart';

class _FakeController extends ValueNotifier<VideoPlayerValue> {
  _FakeController() : super(const VideoPlayerValue(duration: Duration.zero));

  bool get hasAnyListener => hasListeners;
}

VideoPlayerValue _tick({
  bool isPlaying = false,
  bool isInitialized = true,
  Duration position = Duration.zero,
}) {
  return VideoPlayerValue(
    duration: const Duration(seconds: 10),
    position: position,
    isInitialized: isInitialized,
    isPlaying: isPlaying,
  );
}

void main() {
  test('fires onStart when playback begins', () {
    final c = _FakeController();
    var starts = 0;
    PlaybackStartDetector(c, () => starts++);
    c.value = _tick(isPlaying: true);
    expect(starts, 1);
  });

  test('does NOT fire again on subsequent playing ticks (the CPU guard)', () {
    final c = _FakeController();
    var starts = 0;
    PlaybackStartDetector(c, () => starts++);
    c.value = _tick(isPlaying: true, position: const Duration(seconds: 1));
    c.value = _tick(isPlaying: true, position: const Duration(seconds: 2));
    c.value = _tick(isPlaying: true, position: const Duration(seconds: 3));
    expect(starts, 1); // once at the edge, not once per frame
  });

  test('fires again after a pause then resume', () {
    final c = _FakeController();
    var starts = 0;
    PlaybackStartDetector(c, () => starts++);
    c.value = _tick(isPlaying: true); // start -> 1
    c.value = _tick(isPlaying: false); // paused
    c.value = _tick(isPlaying: true); // resume -> 2
    expect(starts, 2);
  });

  test('ignores ticks while uninitialized', () {
    final c = _FakeController();
    var starts = 0;
    PlaybackStartDetector(c, () => starts++);
    c.value = _tick(isPlaying: true, isInitialized: false);
    expect(starts, 0);
  });

  test('dispose detaches (no leak) and stops firing', () {
    final c = _FakeController();
    var starts = 0;
    final d = PlaybackStartDetector(c, () => starts++);
    expect(c.hasAnyListener, isTrue);

    d.dispose();
    expect(c.hasAnyListener, isFalse);

    c.value = _tick(isPlaying: true); // must not fire after dispose
    expect(starts, 0);
  });

  test('null controller never fires and dispose is safe', () {
    var starts = 0;
    final d = PlaybackStartDetector(null, () => starts++);
    d.dispose();
    expect(starts, 0);
  });
}
