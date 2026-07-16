import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reacti_app/helpers/feedback_service.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../logic/video_send_compressor.dart';
import 'camera_capture_screen.dart';
import 'media_preview_screen.dart';
import 'media_review_screen.dart';
import 'widget/media_picker_sheet.dart';

/// Shared media-attachment picker for the 1:1 and group chat screens.
///
/// Owns the staged-attachment state ([selectedImage] + [selectedMediaType])
/// used by the camera path, and the two-option (Gallery / Camera) sheet, so
/// both screens behave identically.
///
/// The gallery path is WhatsApp-style: **multi-select** in the grid → a
/// full-screen [MediaReviewScreen] (shared caption + filmstrip) → each selected
/// item is sent as its own **sealed** media message via the same
/// `sendMessage`/`sendGroupMessage` call a single send uses, so every item is
/// blurred and records a reaction when the recipient opens it. The screen using
/// this mixin supplies the target id, the group flag, and a post-send refresh.
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

  /// Opens the in-app gallery grid (multi-select), then routes the selection
  /// through the review screen and sends the batch.
  Future<void> pickFromGallery(BuildContext context) async {
    final items = await _pickItems(context);
    if (items.isEmpty || !context.mounted) return;
    await _reviewAndSend(context, items);
  }

  /// Shows the multi-select asset grid and maps the picks to review items.
  Future<List<ReviewMediaItem>> _pickItems(BuildContext context) async {
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: _maxBatch,
        requestType: RequestType.common,
        textDelegate: EnglishAssetPickerTextDelegate(),
      ),
    );
    if (assets == null || assets.isEmpty) return const [];

    final items = <ReviewMediaItem>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file == null) continue;
      final type = asset.type == AssetType.video ? 'video' : 'image';
      items.add(ReviewMediaItem(XFile(file.path), type));
    }
    return items;
  }

  /// Opens the review screen for [items]; on Send, dispatches the batch.
  Future<void> _reviewAndSend(
    BuildContext context,
    List<ReviewMediaItem> items,
  ) async {
    final result = await Navigator.of(context).push<MediaReviewResult>(
      MaterialPageRoute(
        builder:
            (_) => MediaReviewScreen(
              initialItems: items,
              onAddMore: () => _pickItems(context),
            ),
      ),
    );
    if (result == null || result.items.isEmpty) return;
    await sendMediaBatch(result.items, result.caption);
  }

  /// Sends every reviewed item as its own sealed media message with the shared
  /// [caption], then refreshes the conversation so they appear.
  ///
  /// The seal/reaction guarantee lives here: each item goes through the same
  /// `sendMessage` the single path uses (server seals every media message), so
  /// N items produce N sealed, reaction-capable messages. Kept as a named method
  /// so that invariant is unit-testable.
  @visibleForTesting
  Future<void> sendMediaBatch(
    List<ReviewMediaItem> items,
    String caption,
  ) async {
    // One send feedback for the batch, like WhatsApp.
    FeedbackService.messageSent();

    // Sequential to avoid a burst of concurrent uploads.
    for (final item in items) {
      await _sendOneSealed(item, caption);
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
  Future<bool> _confirmAndStage(
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
