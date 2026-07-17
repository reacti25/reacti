import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reacti_app/helpers/feedback_service.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../logic/video_send_compressor.dart';
import 'camera_capture_screen.dart';
import 'media_preview_screen.dart';
import 'widget/media_picker_sheet.dart';
import 'widget/whatsapp_asset_picker.dart';

/// One media item staged for sending: a picked/captured file and its kind.
class ReviewMediaItem {
  /// Creates an item for [file] of [mediaType] (`image`/`video`).
  const ReviewMediaItem(this.file, this.mediaType);

  /// The picked or captured media.
  final XFile file;

  /// `'image'` or `'video'`.
  final String mediaType;
}

/// Shared media-attachment picker for the 1:1 and group chat screens.
///
/// Owns the staged-attachment state ([selectedImage] + [selectedMediaType])
/// used by the camera path, and the two-option (Gallery / Camera) sheet, so
/// both screens behave identically.
///
/// The gallery path is WhatsApp-style and stays on one screen: **multi-select**
/// in the grid, with a shared caption, a filmstrip and Send inline in the
/// picker's bottom bar (tapping a filmstrip photo opens the editor for it).
/// Each selected item is then sent as its own **sealed** media message via the
/// same `sendMessage`/`sendGroupMessage` call a single send uses, so every item
/// is blurred and records a reaction when the recipient opens it. The screen
/// using this mixin supplies the target id, the group flag, and a post-send
/// refresh.
mixin MediaPickerMixin<T extends StatefulWidget> on State<T> {
  /// The attachment currently staged for sending (camera path).
  final ValueNotifier<XFile?> selectedImage = ValueNotifier<XFile?>(null);

  /// The media kind (`image`/`video`) of the staged attachment (camera path).
  final ValueNotifier<String?> selectedMediaType = ValueNotifier<String?>(null);

  /// Max items selectable in one batch (matches WhatsApp's cap).
  static const int _maxBatch = 30;

  // --- Hooks the host screen must supply so the batch send can reuse the
  // --- existing, seal-preserving send path. -------------------------------

  /// Conversation target id for sends (peer id for 1:1, room id for a group).
  int get mediaConversationId;

  /// Whether the host is a group conversation.
  bool get isGroupConversation;

  /// Re-fetch the open conversation so freshly sent batch media appears.
  void refreshConversationMedia();

  /// Opens the two-option media sheet: **Gallery** and **Camera**.
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

  /// Opens the WhatsApp-style picker (dense grid + inline caption & send) and
  /// dispatches the selection as a sealed batch with the typed caption.
  Future<void> pickFromGallery(BuildContext context) async {
    final picked = await pickWhatsAppMedia(
      context,
      accent: context.reacti.brandFill,
      onAccent: context.reacti.onBrandFill,
      maxAssets: _maxBatch,
    );
    if (picked == null || !context.mounted) return;

    final items = <ReviewMediaItem>[];
    for (final asset in picked.assets) {
      final file = await asset.file;
      if (file == null) continue;
      final type = asset.type == AssetType.video ? 'video' : 'image';
      // Upload the drawn-on copy when the user opened the pencil editor.
      final path = picked.pathFor(asset.id, file.path);
      items.add(ReviewMediaItem(XFile(path), type));
    }
    if (items.isEmpty) return;
    await sendMediaBatch(items, picked.caption);
  }

  /// Sends every reviewed item as its own sealed media message, with the shared
  /// [caption] on the **last** one, then refreshes the conversation.
  ///
  /// The seal/reaction guarantee lives here: each item goes through the same
  /// `sendMessage` the single path uses (server seals every media message), so
  /// N items produce N sealed, reaction-capable messages. Kept as a named method
  /// so that invariant is unit-testable.
  ///
  /// The caption rides on the last item only. Repeating it on all N (the
  /// original behaviour) printed the same line under every photo; WhatsApp
  /// shows it once. Last rather than first so it reads as a caption under the
  /// whole group instead of stranding it mid-run.
  @visibleForTesting
  Future<void> sendMediaBatch(
    List<ReviewMediaItem> items,
    String caption,
  ) async {
    // One send feedback for the batch, like WhatsApp.
    FeedbackService.messageSent();

    // Sequential to avoid a burst of concurrent uploads.
    for (var i = 0; i < items.length; i++) {
      final isLast = i == items.length - 1;
      await _sendOneSealed(items[i], isLast ? caption : '');
    }
    // Freshly sent items surface via a conversation refresh.
    if (mounted) refreshConversationMedia();
  }

  /// Sends a single review [item] with the shared [caption] through the same
  /// send call the composer uses — preserving the seal / reaction flow.
  Future<void> _sendOneSealed(ReviewMediaItem item, String caption) async {
    final fileToSend = await prepareMediaForSend(item.file, item.mediaType);
    if (isGroupConversation) {
      await sendGroupMessageRx.sendMessage(
        id: mediaConversationId,
        message: caption,
        file: fileToSend,
        type: 'normal',
      );
    } else {
      await sendMessageRx.sendMessage(
        id: mediaConversationId,
        message: caption,
        file: fileToSend,
        type: 'normal',
      );
    }
  }

  /// Opens the full-screen camera and routes a capture through the preview.
  ///
  /// Discarding a capture re-opens a fresh camera; "Use" stages it in the
  /// composer, and closing the camera returns to the chat.
  Future<void> _openCamera(BuildContext context) async {
    while (true) {
      final result = await Navigator.of(context).push<CameraCaptureResult>(
        MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
      );
      if (result == null) return; // camera closed → back to chat
      if (!context.mounted) return;

      final staged = await _confirmAndStage(
        context,
        result.file,
        result.mediaType,
      );
      if (staged) return; // "Use" → staged, done
      if (!context.mounted) return;
      // discarded → loop re-opens a fresh camera
    }
  }

  /// Shows a full-screen preview of [file]; stages it for sending only if the
  /// user confirms. Returns `true` when staged.
  ///
  /// The preview hands back the file to actually send — the edited copy when
  /// the user used its pencil — so a drawn-on capture is what gets staged.
  Future<bool> _confirmAndStage(
    BuildContext context,
    XFile file,
    String type,
  ) async {
    final confirmed = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        builder: (_) => MediaPreviewScreen(file: file, mediaType: type),
      ),
    );

    if (confirmed != null) {
      selectedImage.value = confirmed;
      selectedMediaType.value = type;
      return true;
    }
    return false;
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
