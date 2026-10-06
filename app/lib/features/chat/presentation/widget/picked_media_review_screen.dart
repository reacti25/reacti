// Android gallery: the caption, edit and send step after the system Photo
// Picker (docs/PLAN-android-and-play-store-2026-09-28.md, Step 7).
//
// iOS picks, captions and edits inside one custom grid
// (whatsapp_asset_picker.dart). That grid needs broad photo-library access,
// which Google Play's Photo & Video Permissions policy refuses to a messaging
// app, so Android uses the system picker instead and gets the same filmstrip,
// editor, caption and send controls here, one screen later.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../media_picker_mixin.dart';
import 'image_edit_screen.dart';

/// Whether the gallery uses the system Photo Picker plus [PickedMediaReviewScreen]
/// (Android) instead of the custom in-app grid (iOS).
bool usesSystemPhotoPicker(TargetPlatform platform) =>
    platform == TargetPlatform.android;

/// Switches `image_picker` to the Android system Photo Picker, which needs no
/// media permission (Google Play's Photo & Video policy). Without it,
/// image_picker opens the generic file chooser. Called once from `main()`; a
/// no-op on other platforms.
void enableAndroidPhotoPicker() {
  final picker = ImagePickerPlatform.instance;
  if (picker is ImagePickerAndroid) {
    picker.useAndroidPhotoPicker = true;
  }
}

/// What the review screen hands back: the items to send and the one caption.
typedef PickedMedia = ({List<ReviewMediaItem> items, String caption});

/// File extensions the system picker returns for videos. Everything else it
/// returns is an image (the picker only offers visual media).
const _videoExtensions = {'mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv'};

/// `'video'` for a video file path, `'image'` otherwise, judged by extension.
String mediaTypeForPath(String path) {
  final dot = path.lastIndexOf('.');
  final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  return _videoExtensions.contains(ext) ? 'video' : 'image';
}

/// `'video'` or `'image'` for a file the system picker returned.
///
/// Trusts [XFile.mimeType] when the picker supplied one, and falls back to the
/// extension only when it did not (it is often null on Android). A video
/// mistaken for an image would be sent as a broken photo.
String mediaTypeForFile(XFile file) {
  final mime = file.mimeType;
  if (mime != null && mime.isNotEmpty) {
    return mime.startsWith('video/') ? 'video' : 'image';
  }
  return mediaTypeForPath(file.path);
}

/// Full-screen review of media picked with the Android system Photo Picker.
///
/// Shows the current item large, a filmstrip to switch between items, an Edit
/// action for images (the same editor as iOS), a caption field and Send. Pops
/// a [PickedMedia] on Send, or null when the user backs out.
class PickedMediaReviewScreen extends StatefulWidget {
  /// Creates the review screen for [files] (at least one).
  const PickedMediaReviewScreen({
    super.key,
    required this.files,
    required this.accent,
    required this.onAccent,
    this.editor = editImageFile,
  });

  /// The files the system picker returned, in pick order.
  final List<XFile> files;

  /// Send button fill colour.
  final Color accent;

  /// Send icon colour on [accent].
  final Color onAccent;

  /// Opens the image editor on a path and returns the edited copy's path, or
  /// null when the user backs out. Injectable for tests.
  final Future<String?> Function(BuildContext context, String path) editor;

  @override
  State<PickedMediaReviewScreen> createState() =>
      _PickedMediaReviewScreenState();
}

class _PickedMediaReviewScreenState extends State<PickedMediaReviewScreen> {
  /// Current path per item: the original, or its edited copy once edited.
  late final List<String> _paths = [for (final f in widget.files) f.path];

  /// Kind per item, fixed at pick time (an edit never changes the kind: only
  /// images can be edited, and the editor writes an image).
  late final List<String> _kinds = [
    for (final f in widget.files) mediaTypeForFile(f),
  ];

  /// Index of the item shown large.
  int _current = 0;

  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  bool get _currentIsImage => _kinds[_current] == 'image';

  /// Opens the editor on the current image and keeps the edited copy.
  Future<void> _editCurrent() async {
    final index = _current;
    final edited = await widget.editor(context, _paths[index]);
    if (edited == null || !mounted) return; // backed out: keep what we had
    setState(() => _paths[index] = edited);
  }

  void _send() {
    final PickedMedia result = (
      items: [
        for (var i = 0; i < _paths.length; i++)
          ReviewMediaItem(XFile(_paths[i]), _kinds[i]),
      ],
      caption: _caption.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_currentIsImage)
            IconButton(
              key: const Key('review-edit'),
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
              onPressed: _editCurrent,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: Center(child: _preview(_current))),
            _filmstrip(),
            _captionBar(),
          ],
        ),
      ),
    );
  }

  /// The current item, large. Videos show a play glyph: a full player here
  /// would add nothing the chat's own player does not already do after send.
  Widget _preview(int i) {
    final path = _paths[i];
    if (_kinds[i] == 'video') {
      return Icon(Icons.play_circle_outline, color: Colors.white70, size: 72.w);
    }
    return Image.file(
      File(path),
      key: ValueKey(path), // re-read after an edit writes a new copy
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _brokenImage(),
    );
  }

  /// A thumbnail per item; tapping one shows it large.
  Widget _filmstrip() {
    return SizedBox(
      height: 60.w,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.w),
        itemCount: _paths.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, i) {
          final path = _paths[i];
          final isVideo = _kinds[i] == 'video';
          return GestureDetector(
            key: Key('review-thumb-$i'),
            onTap: () => setState(() => _current = i),
            child: Container(
              width: 52.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: i == _current ? widget.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  isVideo
                      ? const ColoredBox(
                        color: Color(0xFF242424),
                        child: Icon(Icons.videocam, color: Colors.white70),
                      )
                      : Image.file(
                        File(path),
                        key: ValueKey(path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _brokenImage(),
                      ),
            ),
          );
        },
      ),
    );
  }

  /// Caption field and Send, matching the iOS picker's bottom bar.
  Widget _captionBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('review-caption'),
              controller: _caption,
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
          IconButton.filled(
            key: const Key('review-send'),
            tooltip: 'Send ${_paths.length}',
            style: IconButton.styleFrom(backgroundColor: widget.accent),
            icon: Icon(Icons.send_rounded, color: widget.onAccent),
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  Widget _brokenImage() =>
      const Icon(Icons.broken_image_outlined, color: Colors.white38);
}
