import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../networks/auth_token_store.dart';
import '../logic/one_time_media_fetcher.dart';
import '../logic/screenshot_guard.dart';

/// Full-screen, screenshot-protected viewer for a view-once media message.
///
/// Opened when the receiver taps a one-time sealed message (after the normal
/// unblur + reaction-record path has run). It:
///   * blocks screen capture for as long as it is open (via [screenshotGuard]),
///   * fetches the media from the authed private endpoint — an **image** into
///     memory (never a disk cache), a **video** streamed with the bearer header,
///   * releases capture protection and drops its bytes on close.
///
/// It does NOT decide destruction — that is the server's job on the claim
/// (P2d). This widget only guarantees nothing is left on the device: no disk
/// cache, and the in-memory bytes go when the route is popped.
class OneTimeMediaViewer extends StatefulWidget {
  /// Creates a viewer for [url] (the authed endpoint) of kind [mediaType]
  /// (`image` / `video`).
  const OneTimeMediaViewer({
    super.key,
    required this.url,
    required this.mediaType,
  });

  /// The authed one-time-media endpoint URL from the message's `file`.
  final String url;

  /// `'image'` or `'video'`.
  final String mediaType;

  @override
  State<OneTimeMediaViewer> createState() => _OneTimeMediaViewerState();
}

class _OneTimeMediaViewerState extends State<OneTimeMediaViewer> {
  bool get _isVideo => widget.mediaType == 'video';

  /// Image bytes once fetched; null while loading or on a video.
  Uint8List? _bytes;

  /// Video controller once initialized; null on an image.
  VideoPlayerController? _video;

  /// Set when the fetch/init failed, so the viewer shows an error instead of
  /// hanging on a spinner.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Protect capture for the whole time this screen is up.
    screenshotGuard.block();
    _isVideo ? _initVideo() : _loadImage();
  }

  @override
  void dispose() {
    // Release protection so the rest of the app is unaffected, and drop the
    // decoded bytes / streamed controller — nothing persists after view.
    screenshotGuard.allow();
    _video?.dispose();
    super.dispose();
  }

  /// Fetches the image bytes into memory (no disk cache).
  Future<void> _loadImage() async {
    try {
      final bytes = await oneTimeMediaFetcher.fetch(widget.url);
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Streams the video from the authed endpoint with the bearer header.
  Future<void> _initVideo() async {
    final token = AuthTokenStore.instance.token ?? '';
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: {'Authorization': 'Bearer $token'},
    );
    _video = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      controller
        ..setLooping(true)
        ..play();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Center(child: _content())),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_failed) {
      return const Text(
        'This media is no longer available',
        style: TextStyle(color: Colors.white70),
      );
    }
    if (_isVideo) {
      final v = _video;
      if (v == null || !v.value.isInitialized) {
        return const CircularProgressIndicator(color: Colors.white);
      }
      return AspectRatio(
        aspectRatio: v.value.aspectRatio,
        child: VideoPlayer(v),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    // Image.memory, never Image.network / CachedNetworkImage — one-time bytes
    // must not touch a disk cache.
    return Image.memory(bytes, fit: BoxFit.contain);
  }
}
