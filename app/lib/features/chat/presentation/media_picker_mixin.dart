import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'camera_capture_screen.dart';
import 'media_preview_screen.dart';
import 'widget/media_picker_sheet.dart';

/// Shared media-attachment picker for the 1:1 and group chat screens.
///
/// Owns the staged-attachment state ([selectedImage] + [selectedMediaType])
/// and the two-option (Gallery / Camera) sheet, so both screens behave
/// identically and can't drift. The staging contract is unchanged: whatever is
/// picked lands in [selectedImage] + [selectedMediaType] for the send path.
mixin MediaPickerMixin<T extends StatefulWidget> on State<T> {
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

  /// Opens a WhatsApp-style in-app gallery grid (single-select — one file per
  /// send) for images and videos, then routes the pick through the preview.
  Future<void> pickFromGallery(BuildContext context) async {
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.common,
        textDelegate: EnglishAssetPickerTextDelegate(),
      ),
    );
    if (assets == null || assets.isEmpty) return;

    final asset = assets.first;
    final file = await asset.file;
    if (file == null) return;

    final type = asset.type == AssetType.video ? 'video' : 'image';
    if (!context.mounted) return;
    await _confirmAndStage(context, XFile(file.path), type);
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
