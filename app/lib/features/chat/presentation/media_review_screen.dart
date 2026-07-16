import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import '../../../theme/app_theme.dart';

/// One item staged in the review screen: a picked/captured file and its kind.
class ReviewMediaItem {
  /// Creates a review item for [file] of [mediaType] (`image`/`video`).
  const ReviewMediaItem(this.file, this.mediaType);

  /// The picked or captured media.
  final XFile file;

  /// `'image'` or `'video'`.
  final String mediaType;
}

/// What the review screen returns when the user hits Send.
class MediaReviewResult {
  /// Creates a result carrying the [items] to send and the shared [caption].
  const MediaReviewResult(this.items, this.caption);

  /// The media to send, in filmstrip order.
  final List<ReviewMediaItem> items;

  /// One caption applied to every sent item (may be empty).
  final String caption;
}

/// WhatsApp-style review screen shown after picking/capturing media.
///
/// Fills the screen with the current item, a bottom **caption field + Send**,
/// and a **filmstrip** of all selected items (tap to switch, ✕ to remove, ＋ to
/// add more). Pops a [MediaReviewResult] on Send, or `null` if the user backs
/// out with nothing staged. One shared caption is attached to every item; each
/// item is still sent as its own (sealed) media message by the caller.
class MediaReviewScreen extends StatefulWidget {
  /// Creates the review screen for [initialItems].
  ///
  /// [onAddMore] is invoked when the ＋ tile is tapped; it should return any
  /// newly picked items to append (empty/null to add none).
  const MediaReviewScreen({
    super.key,
    required this.initialItems,
    this.onAddMore,
  });

  /// The items to review first (at least one).
  final List<ReviewMediaItem> initialItems;

  /// Picks more items to append; null disables the ＋ tile.
  final Future<List<ReviewMediaItem>?> Function()? onAddMore;

  @override
  State<MediaReviewScreen> createState() => _MediaReviewScreenState();
}

class _MediaReviewScreenState extends State<MediaReviewScreen> {
  late final List<ReviewMediaItem> _items = [...widget.initialItems];
  final _captionController = TextEditingController();

  /// Index of the item currently shown full-screen.
  int _current = 0;

  /// Cached video controllers per item path, so switching the filmstrip doesn't
  /// re-initialize and playback state is preserved.
  final Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void dispose() {
    _captionController.dispose();
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  ReviewMediaItem get _activeItem => _items[_current];

  /// Lazily builds (and caches) a looping controller for a video [item].
  VideoPlayerController _controllerFor(ReviewMediaItem item) {
    return _videoControllers.putIfAbsent(item.file.path, () {
      final c = VideoPlayerController.file(File(item.file.path));
      c.initialize().then((_) {
        if (!mounted) return;
        c
          ..setLooping(true)
          ..play();
        setState(() {});
      });
      return c;
    });
  }

  void _removeCurrent() {
    if (_items.length <= 1) {
      // Removing the last item cancels the whole review.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      final removed = _items.removeAt(_current);
      _videoControllers.remove(removed.file.path)?.dispose();
      if (_current >= _items.length) _current = _items.length - 1;
    });
  }

  Future<void> _addMore() async {
    final added = await widget.onAddMore?.call();
    if (added == null || added.isEmpty || !mounted) return;
    setState(() {
      _items.addAll(added);
      _current = _items.length - 1;
    });
  }

  void _send() {
    Navigator.of(
      context,
    ).pop(MediaReviewResult(_items, _captionController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _preview()),
                SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: _removeCurrent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _filmstrip(),
          _captionBar(),
        ],
      ),
    );
  }

  Widget _preview() {
    final item = _activeItem;
    if (item.mediaType != 'video') {
      return Center(child: Image.file(File(item.file.path)));
    }
    final c = _controllerFor(item);
    if (!c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
      child: Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      ),
    );
  }

  /// Horizontal strip of thumbnails plus an ＋ add-more tile.
  Widget _filmstrip() {
    // A single item with no add-more affordance needs no strip.
    if (_items.length == 1 && widget.onAddMore == null) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 72.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      color: Colors.black,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _items.length; i++) _thumb(i),
          if (widget.onAddMore != null) _addTile(),
        ],
      ),
    );
  }

  Widget _thumb(int i) {
    final item = _items[i];
    final selected = i == _current;
    return GestureDetector(
      onTap: () => setState(() => _current = i),
      child: Container(
        width: 52.w,
        margin: EdgeInsets.only(right: 8.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: selected ? context.reacti.brandFill : Colors.transparent,
            width: 2.w,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child:
              item.mediaType == 'video'
                  ? Container(
                    color: const Color(0xFF333333),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                    ),
                  )
                  : Image.file(File(item.file.path), fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _addTile() {
    return GestureDetector(
      onTap: _addMore,
      child: Container(
        width: 52.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.white54, width: 1.w),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Bottom bar: the shared caption field and the round Send button.
  Widget _captionBar() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.black,
        padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _captionController,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add a caption…',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF242424),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            GestureDetector(
              key: const Key('review_send_button'),
              onTap: _send,
              child: Container(
                padding: EdgeInsets.all(14.sp),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.reacti.brandFill,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: context.reacti.onBrandFill,
                  size: 22.w,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
