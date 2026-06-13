import 'dart:developer';
import 'dart:io';

import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../networks/api_access.dart';

/// Message composer pinned to the bottom of an inbox screen.
///
/// Renders an optional selected-media preview, a multiline text field, an
/// attachment button and a send button. On send it notifies the parent via
/// [onSend] (for optimistic insertion) and then dispatches the message
/// through `sendGroupMessageRx` or `sendMessageRx` depending on [isGroup],
/// forwarding upload progress through [onProgress] and completion through
/// [onSuccess]. Used by [InboxScreen] and [GroupInboxScreen].
///
/// The staged-media preview lives *inside* the composer container (attached
/// to the input row), not floating above it, so a picked-but-unsent image
/// can't be mistaken for an already-sent message. The send button lights up
/// (filled accent) whenever there is something to send.
class SendMessageWidget extends StatefulWidget {
  /// Creates the message composer.
  ///
  /// [id] is the conversation target (peer id or group id) and
  /// [messageController] backs the text field. [image] / [mediaType] are the
  /// shared notifiers holding the currently selected attachment, while
  /// [onTapMedia] opens the attachment picker. [replyToId] links the
  /// outgoing message to a quoted message. [isGroup] selects the group vs.
  /// one-to-one send path. [onSend], [onProgress] and [onSuccess] report the
  /// optimistic send, upload progress and final result to the parent.
  /// [blockSendWhenViolated], [file] and [type] are accepted for
  /// compatibility but not central to the send flow.
  const SendMessageWidget({
    super.key,
    required this.id,
    required this.messageController,
    this.blockSendWhenViolated = false,
    this.file,
    this.onTapMedia,
    this.type,
    this.image,
    this.mediaType,
    this.replyToId,
    required this.isGroup,
    this.onSend,
    this.onProgress,
    this.onSuccess,
  });

  /// A pre-selected attachment file, if any.
  final XFile? file;

  /// Identifier of the conversation target (peer user id or group id).
  final int id;

  /// Controller backing the message text field.
  final TextEditingController messageController;

  /// Whether sending should be blocked after a policy violation.
  final bool blockSendWhenViolated;

  /// Invoked when the attachment button is tapped.
  final VoidCallback? onTapMedia;

  /// Optional message-type hint supplied by the parent.
  final String? type;

  /// Shared notifier holding the currently selected attachment.
  final ValueNotifier<XFile?>? image;

  /// Shared notifier holding the media kind of the selected attachment.
  final ValueNotifier<String?>? mediaType;

  /// Identifier of the message being replied to, if this is a reply.
  final int? replyToId;

  /// Whether the composer targets a group conversation.
  final bool isGroup;

  /// Called when the user sends, so the parent can insert an optimistic
  /// message keyed by `tempId` before the network request completes.
  final Function(String text, XFile? file, String mediaType, int tempId)?
  onSend;

  /// Called repeatedly with the upload progress (0.0–1.0) of the message.
  final Function(int tempId, double progress)? onProgress;

  /// Called when the send finishes, reporting success or failure.
  final Function(int tempId, bool success)? onSuccess;

  /// Creates the mutable state for the composer.
  @override
  State<SendMessageWidget> createState() => _SendMessageWidgetState();
}

/// State for [SendMessageWidget]; builds the composer UI and handles the
/// send action.
class _SendMessageWidgetState extends State<SendMessageWidget> {
  /// Builds the composer container: an optional staged-attachment preview
  /// directly above the input row (attachment button, text field, send
  /// button), all inside one rounded surface so they read as a single unit.
  ///
  /// Rebuilt via a merged [Listenable] on the text controller and the shared
  /// attachment notifiers, so the preview and the send button's lit/resting
  /// state stay in sync with what is currently staged.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 16.h,
        left: 16.w,
        right: 16.w,
        top: 12.h,
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          widget.messageController,
          widget.image,
          widget.mediaType,
        ]),
        builder: (context, _) {
          final stagedFile = widget.image?.value;
          final isVideo = widget.mediaType?.value == 'video';
          final hasText = widget.messageController.text.trim().isNotEmpty;
          final canSend = stagedFile != null || hasText;

          return Container(
            key: const Key('composer_container'),
            decoration: BoxDecoration(
              color: AppColors.c242424,
              borderRadius: BorderRadius.circular(20.r),
            ),
            padding: EdgeInsets.all(6.sp),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stagedFile != null)
                  _StagedAttachmentPreview(
                    file: stagedFile,
                    isVideo: isVideo,
                    onRemove: _clearAttachment,
                  ),
                _buildInputRow(canSend: canSend),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The input row: attachment button, the multiline text field, and the
  /// send button (lit when [canSend]).
  Widget _buildInputRow({required bool canSend}) {
    return Row(
      spacing: 8.w,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildAttachmentButton(),
        Expanded(child: _buildTextField()),
        _buildSendButton(canSend: canSend),
      ],
    );
  }

  /// The circular attachment (media picker) button.
  Widget _buildAttachmentButton() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: GestureDetector(
        onTap: widget.onTapMedia,
        child: Container(
          padding: EdgeInsets.all(12.sp),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.c333333,
          ),
          child: SvgPicture.asset(Assets.icons.attachmentIcon, width: 16.w),
        ),
      ),
    );
  }

  /// The multiline message text field.
  Widget _buildTextField() {
    return TextFormField(
      controller: widget.messageController,
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        hintText: "Type a message...",
        hintStyle: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
          fontSize: 14.sp,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(color: AppColors.cFFFFFF),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(color: Colors.white70),
        ),
      ),
      maxLines: 3,
      minLines: 1,
      textInputAction: TextInputAction.newline,
      style: TextFontStyle.headline14w500CFFFFFFPoppins,
    );
  }

  /// The send button. Filled with the accent colour when [canSend] (something
  /// staged or typed), resting grey otherwise — so it visibly signals that an
  /// action is still required to actually send the staged media.
  Widget _buildSendButton({required bool canSend}) {
    return InkWell(
      onTap: _handleSend,
      customBorder: const CircleBorder(),
      child: Container(
        key: const Key('composer_send_button'),
        padding: EdgeInsets.all(12.sp),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: canSend ? AppColors.allPrimaryColor : AppColors.c333333,
        ),
        child: SvgPicture.asset(
          Assets.icons.sendIcon,
          width: 16.w,
          // Tint the glyph dark so it stays legible on the lit accent fill.
          colorFilter:
              canSend
                  ? const ColorFilter.mode(AppColors.c000000, BlendMode.srcIn)
                  : null,
        ),
      ),
    );
  }

  /// Clears the staged attachment (and its media-type) from the shared
  /// notifiers, hiding the preview.
  void _clearAttachment() {
    widget.image?.value = null;
    widget.mediaType?.value = null;
  }

  /// Validates, optimistically reports the send to the parent, clears the
  /// composer, then dispatches the message through the appropriate rx data
  /// source — group or one-to-one — wiring progress and completion callbacks.
  ///
  /// Behaviour is unchanged from before the in-composer layout change: an
  /// empty composer (no text and no attachment) is a no-op, and the
  /// `type: "normal"` payload / optimistic-insert contract are preserved.
  void _handleSend() {
    final messageText = widget.messageController.text.trim();
    final messageFile = widget.image?.value;
    final mediaType = widget.mediaType?.value ?? 'text';

    if (messageText.isEmpty && messageFile == null) {
      return; // Prevent sending if the message is empty
    }

    // Temporary id correlating the optimistic message with the later
    // progress/success callbacks.
    final tempId = DateTime.now().millisecondsSinceEpoch;

    if (widget.onSend != null) {
      widget.onSend!(messageText, messageFile, mediaType, tempId);
    }

    widget.messageController.clear();
    if (widget.image != null) widget.image!.value = null;
    if (widget.mediaType != null) widget.mediaType!.value = null;

    if (widget.isGroup) {
      log("Message is =========> $messageText");
      // Send group message
      if (widget.replyToId != null) {
        log("This is reply with id ${widget.replyToId}");
      } else {
        log("This is not a reply");
      }
      sendGroupMessageRx
          .sendMessage(
            id: widget.id,
            message: messageText,
            file: messageFile,
            type: "normal",
            replyToId: widget.replyToId,
            onSendProgress: (sent, total) {
              if (total != -1) {
                final progress = sent / total;
                if (widget.onProgress != null) {
                  widget.onProgress!(tempId, progress);
                }
              }
            },
          )
          .then((success) {
            if (widget.onSuccess != null) {
              widget.onSuccess!(tempId, success);
            }
            if (success) {
              getAllChatRx.getAllChat();
            }
          });
      return;
    }
    sendMessageRx
        .sendMessage(
          id: widget.id,
          message: messageText,
          file: messageFile,
          type: "normal",
          replyToId: widget.replyToId,
          onSendProgress: (sent, total) {
            if (total != -1) {
              final progress = sent / total;
              if (widget.onProgress != null) {
                widget.onProgress!(tempId, progress);
              }
            }
          },
        )
        .then((success) {
          if (widget.onSuccess != null) {
            widget.onSuccess!(tempId, success);
          }
          if (success) {
            getAllChatRx.getAllChat();
          }
        });
  }
}

/// The staged-attachment chip shown inside the composer: a compact thumbnail
/// with a corner × remove control and a short "ready to send" label, so a
/// picked image/video clearly reads as *about to be sent*, not already sent.
class _StagedAttachmentPreview extends StatelessWidget {
  /// Creates the staged-attachment preview.
  ///
  /// [file] is the staged attachment, [isVideo] selects the video placeholder
  /// vs. an image thumbnail, and [onRemove] un-stages it.
  const _StagedAttachmentPreview({
    required this.file,
    required this.isVideo,
    required this.onRemove,
  });

  /// The currently staged attachment.
  final XFile file;

  /// Whether the staged attachment is a video (shows a placeholder instead of
  /// decoding a frame).
  final bool isVideo;

  /// Called when the × control is tapped to un-stage the attachment.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('staged_attachment_preview'),
      padding: EdgeInsets.only(left: 6.w, right: 6.w, top: 6.h, bottom: 10.h),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: SizedBox(
                  height: 56.h,
                  width: 56.w,
                  child:
                      isVideo
                          ? Container(
                            color: AppColors.c000000,
                            child: Icon(
                              Icons.videocam_rounded,
                              color: AppColors.cFFFFFF,
                              size: 24.sp,
                            ),
                          )
                          : Image.file(
                            File(file.path),
                            fit: BoxFit.cover,
                            // A missing/undecodable staged file shows a neutral
                            // placeholder rather than crashing the composer.
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  color: AppColors.c333333,
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: AppColors.cFFFFFF,
                                    size: 24.sp,
                                  ),
                                ),
                          ),
                ),
              ),
              Positioned(
                right: -6.w,
                top: -6.h,
                child: GestureDetector(
                  key: const Key('remove_staged_attachment'),
                  onTap: onRemove,
                  child: Container(
                    padding: EdgeInsets.all(2.sp),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.c000000,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16.sp,
                      color: AppColors.cFFFFFF,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: Text(
              isVideo ? '1 video ready to send' : '1 photo ready to send',
              style: TextFontStyle.headline14w500CFFFFFFPoppins,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
