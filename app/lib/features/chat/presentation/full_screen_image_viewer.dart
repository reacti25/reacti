import 'package:flutter/material.dart';

import '../../../common_widget/inbox_custom_network_image.dart';

/// A full-screen, pinch-to-zoom viewer for a chat media image.
///
/// Opened by tapping an image message; the close button returns to the chat.
/// Videos already have their own full-screen control, so this is images only.
class FullScreenImageViewer extends StatelessWidget {
  /// Creates the viewer for the image at [url].
  const FullScreenImageViewer({super.key, required this.url});

  /// The image URL to display full-screen.
  final String url;

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
        ],
      ),
    );
  }
}
