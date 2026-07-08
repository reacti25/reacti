import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

import 'network_status.dart';
import 'video_controller_cache.dart';

/// What, if anything, to prefetch for a freshly received message.
enum PrefetchAction {
  /// Nothing to prefetch (no media, a local/optimistic path, or video off Wi-Fi).
  none,

  /// Warm the image cache so the blurred media opens instantly.
  image,

  /// Warm the video controller cache (Wi-Fi only).
  video,
}

/// Prefetches received media so it is already cached by the time the recipient
/// taps the blurred placeholder to view it — cutting `media_load_ms` on open.
///
/// Branch 2.2 of `docs/PLAN-media-timing-and-speed-2026-06-23.md`. Driven by the
/// realtime (Pusher) receipt handlers of the chat screens, one message at a
/// time, so the per-item caches (image disk cache, the 50-entry
/// [VideoControllerCache]) bound total usage — no separate cap needed.
///
/// Both images and videos prefetch on any live connection; nothing prefetches
/// while offline. Warming a video is a light controller-initialize (first frame
/// + head buffer, not the whole file), and videos are compressed on send now,
/// so it's cheap enough to do off Wi-Fi — making a video open instantly even on
/// a weak cellular connection.
class MediaPrefetch {
  MediaPrefetch._();

  /// Pure decision: what to prefetch for [file]/[mediaType] on [network]
  /// (`wifi`|`cellular`|`none`|`unknown`). Side-effect free and unit-testable.
  ///
  /// Only remote (`http`) media is eligible — a local/optimistic path is the
  /// sender's own in-flight message, already on disk. Video prefetch is skipped
  /// only when offline (`none`); on any live connection the controller is warmed
  /// so the video opens without a load stall.
  static PrefetchAction decide({
    required String? file,
    required String? mediaType,
    required String network,
  }) {
    if (file == null || !file.startsWith('http')) return PrefetchAction.none;
    if (mediaType == 'image') return PrefetchAction.image;
    if (mediaType == 'video') {
      // ponytail: warm on wifi/cellular/unknown; only skip when offline. If
      // mobile-data cost ever bites, gate this back to wifi.
      return network == 'none' ? PrefetchAction.none : PrefetchAction.video;
    }
    return PrefetchAction.none;
  }

  /// Prefetches the media of a received message (fire-and-forget). Reads the
  /// current network class from [NetworkStatus]; never throws into the caller.
  static void onMessageReceived({
    required String? file,
    required String? mediaType,
  }) {
    try {
      final action = decide(
        file: file,
        mediaType: mediaType,
        network: NetworkStatus.instance.current,
      );
      switch (action) {
        case PrefetchAction.image:
          _warmImage(file!);
        case PrefetchAction.video:
          VideoControllerCache.precacheVideos([file!]);
        case PrefetchAction.none:
          break;
      }
    } catch (_) {
      // Prefetch is best-effort; a failure must never disrupt message handling.
    }
  }

  /// Kicks the image into the shared cache by resolving its provider and
  /// dropping the listener once it completes — precacheImage's effect without
  /// needing a BuildContext.
  static void _warmImage(String url) {
    final stream = CachedNetworkImageProvider(
      url,
    ).resolve(ImageConfiguration.empty);
    ImageStreamListener? listener;
    listener = ImageStreamListener(
      (_, _) => stream.removeListener(listener!),
      onError: (_, _) => stream.removeListener(listener!),
    );
    stream.addListener(listener);
  }
}
