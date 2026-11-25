import 'package:flutter/material.dart';

import '../../../common_widget/inbox_custom_network_image.dart';

/// A full-screen, pinch-to-zoom viewer for a chat media image.
///
/// Opened by tapping an image message; the close button returns to the chat.
/// A one-time photo opens it by itself and passes [closesIn]. Videos already
/// have their own full-screen control, so this is images only.
class FullScreenImageViewer extends StatelessWidget {
  /// Creates the viewer for the image at [url].
  const FullScreenImageViewer({super.key, required this.url, this.closesIn});

  /// The image URL to display full-screen.
  final String url;

  /// For a one-time photo: how long until the chat closes this view. Shows a
  /// ring that empties over that time, so the photo vanishing is expected.
  /// The ring only shows the time; the chat bubble does the closing.
  final Duration? closesIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: InboxCustomNetworkImage(
                  urls: url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          if (closesIn != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _CountdownRing(
                    key: const Key('one-time-countdown'),
                    length: closesIn!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A ring around a "1" that empties over [length]: the time a one-time photo
/// has left on screen.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({super.key, required this.length});

  /// How long the ring takes to empty.
  final Duration length;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: length,
            builder:
                (_, left, _) => CircularProgressIndicator(
                  value: left,
                  strokeWidth: 2.5,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
          ),
          const Text(
            '1',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
