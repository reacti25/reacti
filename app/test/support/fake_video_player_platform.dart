// A no-op fake for the video_player platform interface.
//
// Screens that render a video/reaction message build a FlickManager around a
// VideoPlayerController. Under `flutter test` the real platform never creates
// the player, so `initialize()` leaves a pending timer and the test binding's
// "A Timer is still pending" invariant fails on teardown.
//
// This fake makes every platform call resolve immediately — create returns a
// fake player id, the event stream emits a single `initialized` event so the
// controller completes initialization, and there are no timers. Install it
// with [installFakeVideoPlayerPlatform] in setUp; the previous platform is
// returned so it can be restored in tearDown.

import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A [VideoPlayerPlatform] that resolves every call synchronously and starts
/// no timers, so video widgets can be pumped in `flutter test`.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream<VideoEvent>.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 1),
      size: const Size(1, 1),
    ),
  );

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.shrink();

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

/// Installs the [FakeVideoPlayerPlatform] and returns the platform it replaced
/// so a test can restore it in tearDown.
VideoPlayerPlatform installFakeVideoPlayerPlatform() {
  final previous = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  return previous;
}
