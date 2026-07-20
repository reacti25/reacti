import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import '../../../theme/app_theme.dart';

/// Full-screen confirm step shown after a **video** is captured.
///
/// Pops the [XFile] to send when the user confirms and `null` when they
/// discard, so the caller can offer another capture.
///
/// Photos do not come here: they go straight into the editor, which doubles as
/// their preview (WhatsApp shows its edit tools the moment the shutter fires).
/// This screen has no pencil because the editor cannot trim a video.
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

  bool get _isVideo => widget.mediaType == 'video';

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
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.only(right: 20.w, bottom: 24.h),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(widget.file),
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
      return Center(child: Image.file(File(widget.file.path)));
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
