import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import '../../../theme/app_theme.dart';
import 'widget/image_edit_screen.dart';

/// Full-screen confirm step shown after a photo/video is picked or captured.
///
/// Pops the [XFile] to send when the user confirms — the **edited copy** if
/// they used the pencil, otherwise the original — and `null` when they discard,
/// so the caller can offer another capture. Reused for both the gallery and the
/// camera flows.
class MediaPreviewScreen extends StatefulWidget {
  /// Creates a preview for [file] of the given [mediaType] (`image`/`video`).
  const MediaPreviewScreen({
    super.key,
    required this.file,
    required this.mediaType,
  });

  /// The picked/captured media to preview.
  final XFile file;

  /// `'image'` or `'video'`.
  final String mediaType;

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _video;

  /// The file this screen will hand back — swapped for an edited copy when the
  /// user runs the capture through the pencil.
  late XFile _file = widget.file;

  bool get _isVideo => widget.mediaType == 'video';

  /// Opens the same editor the gallery filmstrip uses on the capture.
  ///
  /// Photos only: editing a video would need a trimmer, which the editor does
  /// not do — so the pencil is hidden for them.
  Future<void> _edit() async {
    final edited = await editImageFile(context, _file.path);
    if (edited == null || !mounted) return; // backed out — keep what we had
    setState(() => _file = XFile(edited));
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _video = VideoPlayerController.file(File(widget.file.path))
        ..initialize().then((_) {
          if (!mounted) return;
          _video!
            ..setLooping(true)
            ..play();
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final v = _video;
    if (v == null || !v.value.isInitialized) return;
    setState(() => v.value.isPlaying ? v.pause() : v.play());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _media()),
          SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // WhatsApp puts an edit toolbar on a fresh capture too, not
                // just on gallery picks.
                if (!_isVideo)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 26),
                    onPressed: _edit,
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.only(right: 20.w, bottom: 24.h),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(_file),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 22.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      color: context.reacti.brandFill,
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Use',
                          style: TextStyle(
                            color: context.reacti.onBrandFill,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: context.reacti.onBrandFill,
                          size: 20.w,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _media() {
    if (!_isVideo) {
      // Keyed on the path so an edit swaps the image instead of serving the
      // decoded original from cache.
      return Center(
        child: Image.file(File(_file.path), key: ValueKey(_file.path)),
      );
    }
    final v = _video;
    if (v == null || !v.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: Center(
        child: AspectRatio(
          aspectRatio: v.value.aspectRatio,
          child: VideoPlayer(v),
        ),
      ),
    );
  }
}
