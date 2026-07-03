import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reacti_app/helpers/navigation_service.dart';

import 'camera_capture_screen.dart';
import 'media_preview_screen.dart';
import 'widget/media_picker_sheet.dart';

/// Known video file extensions, used to classify a picked file when its MIME
/// type is unavailable.
const _videoExtensions = <String>{
  'mp4',
  'mov',
  'm4v',
  'avi',
  'mkv',
  'webm',
  '3gp',
  'flv',
  'wmv',
  'mpeg',
  'mpg',
};

/// Whether a picked media file is a video.
///
/// `image_picker`'s [ImagePicker.pickMedia] returns one [XFile] that may be an
/// image or a video, so the caller must classify it to stage the correct media
/// type. The file's [mimeType] is authoritative when present; otherwise the
/// file extension is used.
bool isVideoMedia(String path, {String? mimeType}) {
  if (mimeType != null) return mimeType.startsWith('video/');
  final extension =
      path.contains('.') ? path.split('.').last.toLowerCase() : '';
  return _videoExtensions.contains(extension);
}

/// Shared media-attachment picker for the 1:1 and group chat screens.
///
/// Owns the staged-attachment state ([selectedImage] + [selectedMediaType])
/// and the two-option (Gallery / Camera) sheet, so both screens behave
/// identically and can't drift. The staging contract is unchanged: whatever is
/// picked lands in [selectedImage] + [selectedMediaType] for the send path.
mixin MediaPickerMixin<T extends StatefulWidget> on State<T> {
  /// Picker used to select images and videos for sending.
  final ImagePicker _mediaPicker = ImagePicker();

  /// The attachment currently staged for sending.
  final ValueNotifier<XFile?> selectedImage = ValueNotifier<XFile?>(null);

  /// The media kind (`image`/`video`) of the staged attachment.
  final ValueNotifier<String?> selectedMediaType = ValueNotifier<String?>(null);

  /// Opens the two-option media sheet: **Gallery** (image or video in one flow)
  /// and **Camera** (an inline Photo/Video choice).
  Future<void> showMediaPicker(BuildContext context) {
    return _showOptionsSheet(context, [
      MediaPickerOption('Gallery', () {
        NavigationService.goBack;
        pickFromGallery(context);
      }, icon: Icons.photo_library_rounded),
      MediaPickerOption('Camera', () {
        NavigationService.goBack;
        _openCamera(context);
      }, icon: Icons.photo_camera_rounded),
    ]);
  }

  /// Picks an image or video from the gallery in a single flow, inferring the
  /// media kind from the returned file, then routes it through the preview.
  Future<void> pickFromGallery(BuildContext context) async {
    final XFile? media = await _mediaPicker.pickMedia(imageQuality: 70);
    if (media == null) return;

    final type =
        isVideoMedia(media.path, mimeType: media.mimeType) ? 'video' : 'image';
    if (!context.mounted) return;
    await _confirmAndStage(context, XFile(media.path), type);
  }

  /// Opens the full-screen camera (with a Photo/Video mode toggle) and routes
  /// the capture through the preview. A WhatsApp-style unified camera, so no
  /// inline photo-vs-video choice is needed.
  Future<void> _openCamera(BuildContext context) async {
    final result = await Navigator.of(context).push<CameraCaptureResult>(
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
    if (result == null) return;

    if (context.mounted) {
      await _confirmAndStage(context, result.file, result.mediaType);
    }
  }

  /// Shows a full-screen preview of [file]; stages it for sending only if the
  /// user confirms, so they can discard and pick another instead.
  Future<void> _confirmAndStage(
    BuildContext context,
    XFile file,
    String type,
  ) async {
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MediaPreviewScreen(file: file, mediaType: type),
      ),
    );

    if (confirmed == true) {
      selectedImage.value = file;
      selectedMediaType.value = type;
    }
  }

  /// Shows a rounded modal bottom sheet listing [options].
  Future<void> _showOptionsSheet(
    BuildContext context,
    List<MediaPickerOption> options,
  ) {
    return showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      builder: (_) => MediaPickerSheet(options: options),
    );
  }
}
