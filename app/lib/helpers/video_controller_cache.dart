// ignore_for_file: deprecated_member_use

import 'package:flick_video_player/flick_video_player.dart';
import 'package:video_player/video_player.dart';

/// Process-wide cache of video player controllers keyed by video URL.
///
/// Reusing controllers avoids re-buffering the same remote video as the user
/// scrolls a chat, and an LRU-style cap keeps memory bounded. Used by chat
/// media widgets that render network videos.
class VideoControllerCache {
  /// Cached [VideoPlayerController] per video URL.
  // Map to hold the VideoPlayerController for each video URL
  static final Map<String, VideoPlayerController> _controllers = {};

  /// Cached [FlickManager] per video URL, wrapping the matching controller.
  static final Map<String, FlickManager> _flickManagers = {};

  /// Maximum number of videos kept cached before the least-recently-used is
  /// evicted.
  ///
  /// Kept small and WELL under iOS's hard limit on simultaneous video decoders
  /// (AVPlayer render pipelines, ~16). Each cached [FlickManager] initializes
  /// its controller (an AVPlayer) eagerly, so an unbounded/large cache — filled
  /// by scrolling, realtime prefetch and inbox precache — accumulates players
  /// until iOS refuses to decode and EVERY video renders black at once. A chat
  /// shows only a couple of videos on screen, so a handful is plenty.
  static const int maxCachedVideos = 6;

  /// Returns the cached controller for [url], creating one if absent.
  // Retrieve a cached VideoPlayerController or create a new one if it doesn't exist
  static VideoPlayerController getVideoController(String url) {
    if (_controllers.containsKey(url)) {
      return _controllers[url]!;
    }

    // Create a new controller if not found
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[url] = controller;
    return controller;
  }

  /// Returns the cached [FlickManager] for [url], creating one if absent.
  ///
  /// Enforces [maxCachedVideos] before creating a new manager, and LRU-touches
  /// an existing one. The created manager does not autoplay.
  // Retrieve a cached FlickManager or create a new one if it doesn't exist
  static FlickManager getFlickManager(String url) {
    final existing = _flickManagers[url];
    if (existing != null) {
      // LRU touch: re-insert so the most-recently-used entry moves to the end.
      // Eviction removes the FIRST (oldest) key, so this guarantees the video
      // the user is actually watching is never the one evicted+disposed.
      _flickManagers.remove(url);
      _flickManagers[url] = existing;
      final controller = _controllers.remove(url);
      if (controller != null) _controllers[url] = controller;
      return existing;
    }

    _enforceCacheLimit();

    // Retrieve or create FlickManager based on the video URL
    final controller = getVideoController(url);
    final flickManager = FlickManager(
      videoPlayerController: controller,
      autoPlay: false,
    );

    _flickManagers[url] = flickManager;
    return flickManager;
  }

  /// Warms the cache by creating managers for every URL in [urls].
  ///
  /// URLs already cached are skipped so playback feels instant once the user
  /// reaches that video.
  // Pre-cache a list of videos
  static void precacheVideos(List<String> urls) {
    for (var url in urls) {
      if (!_flickManagers.containsKey(url)) {
        getFlickManager(url);
      }
    }
  }

  /// Evicts and disposes the oldest cached video once the cap is reached.
  ///
  /// Keeps both [_flickManagers] and [_controllers] in sync so memory and
  /// platform resources are released.
  // Enforce a limit on the number of cached video managers
  static void _enforceCacheLimit() {
    if (_flickManagers.length >= maxCachedVideos) {
      // Remove the oldest cached video manager
      final firstKey = _flickManagers.keys.first;
      _flickManagers[firstKey]?.dispose();
      _flickManagers.remove(firstKey);
      _controllers[firstKey]?.dispose();
      _controllers.remove(firstKey);
    }
  }

  /// Pauses every cached video except the one identified by [currentUrl].
  ///
  /// Ensures only one chat video plays at a time as the user scrolls.
  // Pause all other playing videos
  static void pauseAllOtherVideos(String currentUrl) {
    for (var url in _flickManagers.keys) {
      if (url != currentUrl) {
        _flickManagers[url]?.flickControlManager?.pause();
      }
    }
  }

  /// Disposes and removes every cached controller and manager.
  ///
  /// Call when leaving a media-heavy screen to free all video resources.
  // Clear all cached controllers
  static Future<void> clear() async {
    for (var c in _controllers.values) {
      await c.dispose();
    }
    for (var fm in _flickManagers.values) {
      fm.dispose();
    }

    _controllers.clear();
    _flickManagers.clear();
  }
}
