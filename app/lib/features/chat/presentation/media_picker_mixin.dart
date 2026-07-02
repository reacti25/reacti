import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/toast.dart';

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
        pickFromGallery();
      }, icon: Icons.photo_library_rounded),
      MediaPickerOption('Camera', () {
        NavigationService.goBack;
        _pickFromCamera(context);
      }, icon: Icons.photo_camera_rounded),
    ]);
  }

  /// Picks an image or video from the gallery in a single flow, inferring the
  /// media kind from the returned file.
  Future<void> pickFromGallery() async {
    final XFile? media = await _mediaPicker.pickMedia(imageQuality: 70);

    if (media != null) {
      selectedImage.value = XFile(media.path);
      selectedMediaType.value =
          isVideoMedia(media.path, mimeType: media.mimeType)
              ? 'video'
              : 'image';
    }
  }

  /// Presents the inline Photo/Video choice for the camera, then captures with
  /// the matching picker.
  ///
  /// `image_picker`'s camera source needs the capture kind up front, so a true
  /// in-camera photo/video toggle isn't possible here; a unified custom camera
  /// is a deferred fast-follow (see the media-picker plan).
  Future<void> _pickFromCamera(BuildContext context) {
    return _showOptionsSheet(context, [
      MediaPickerOption('Photo', () {
        NavigationService.goBack;
        _captureImage();
      }, icon: Icons.photo_camera_rounded),
      MediaPickerOption('Video', () {
        NavigationService.goBack;
        _captureVideo();
      }, icon: Icons.videocam_rounded),
    ]);
  }

  /// Captures an image from the camera and stages it as the attachment.
  Future<void> _captureImage() async {
    final XFile? image = await _mediaPicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (image != null) {
      selectedImage.value = XFile(image.path);
      selectedMediaType.value = 'image';
    }
  }

  /// Records a video with the camera and stages it as the attachment,
  /// surfacing a toast if recording fails.
  Future<void> _captureVideo() async {
    try {
      final XFile? video = await _mediaPicker.pickVideo(
        source: ImageSource.camera,
      );

      if (video != null) {
        selectedImage.value = XFile(video.path);
        selectedMediaType.value = 'video';
      }
    } catch (e) {
      log('Error picking camera video: $e');
      ToastUtil.showErrorMessage('Recording failed: $e');
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
