import 'dart:io';
import 'dart:ui';

import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:video_player/video_player.dart';

import '../../../../common_widget/inbox_custom_network_image.dart';
import '../../../../constants/text_font_style.dart';
import '../../../../helpers/ui_helpers.dart';
import '../../../../helpers/video_controller_cache.dart';
import 'custom_video_controls.dart';

/// Chat bubble for an outgoing (sent) message in a one-to-one or group
/// conversation.
///
/// Renders the optional quoted reply, the message media or reaction video,
/// and the text bubble with timestamp. For locally-pending messages it also
/// overlays an upload-progress indicator. Used by [InboxScreen] and
/// [GroupInboxScreen] for messages whose sender is the current user.
class SenderMessageWidget extends StatefulWidget {
  /// Creates a sent-message bubble.
  ///
  /// [message] is the text body and [time] its timestamp. [file] and
  /// [mediaType] describe an optional attachment, while [messageType] selects
  /// the reaction layout when it equals `reaction`. [messageId] identifies
  /// the message and [receiverId] the peer. [isLocal], [localPath] and
  /// [uploadProgress] drive optimistic rendering of an in-flight upload.
  /// [onLongPressDelete] triggers the delete dialog, [onReply] handles
  /// swipe-to-reply, and [replyTo]/[onTapReply] drive the quoted preview.
  /// [isBlocked]/[isBlur] carry block and blur state, and [isHighlighted]
  /// tints the bubble when it is the target of a reply jump.
  const SenderMessageWidget({
    super.key,
    required this.message,
    this.time,
    this.file,
    this.mediaType,
    this.isBlocked,
    required this.messageId,
    this.receiverId,
    required this.onLongPressDelete,
    required this.onReply,
    this.isLocal = false,
    this.localPath,
    this.uploadProgress,
    this.replyTo,
    this.onTapReply,
    this.messageType,
    this.isBlur,
    this.isHighlighted = false,
  });
  /// Whether the bubble is the current target of a reply jump (tinted).
  final bool isHighlighted;

  /// Blur state of the message media; loosely typed to tolerate API variation.
  final dynamic isBlur;

  /// The quoted message this bubble replies to; loosely typed.
  final dynamic replyTo;

  /// Invoked with a message id when the quoted-reply preview is tapped.
  final Function(int)? onTapReply;

  /// Server-side message kind; `reaction` selects the reaction bubble layout.
  final String? messageType;

  /// Whether the message is an optimistic local entry still being uploaded.
  final bool isLocal;

  /// Filesystem path of the local media while [isLocal] is true.
  final String? localPath;

  /// Upload progress in the range 0.0–1.0 for an in-flight local message.
  final double? uploadProgress;

  /// Identifier of this message.
  final int messageId;

  /// Identifier of the peer receiving the message.
  final int? receiverId;

  /// Whether the conversation is blocked.
  final bool? isBlocked;

  /// Text body of the sent message.
  final String message;

  /// Human-readable timestamp shown beneath the message.
  final String? time;

  /// URL or local path of the attached media file, if any.
  final String? file;

  /// Media kind of [file] (`image`, `video`, `reaction`).
  final String? mediaType;

  /// Invoked on long-press to offer deletion of this message.
  final VoidCallback onLongPressDelete;

  /// Invoked on swipe-to-reply so the parent can stage a reply to this bubble.
  final VoidCallback onReply;

  /// Creates the mutable state that manages video playback.
  @override
  State<SenderMessageWidget> createState() => _SenderMessageWidgetState();
}

/// State for [SenderMessageWidget].
///
/// Owns the video controller, deciding between a per-message file-backed
/// controller (for local uploads) and a shared cached network controller,
/// and rebuilds the controller when the logical video source changes.
class _SenderMessageWidgetState extends State<SenderMessageWidget>
    with AutomaticKeepAliveClientMixin {
  /// Keeps this list item alive while off-screen to preserve playback state.
  @override
  bool get wantKeepAlive => true;

  /// Whether the message carries a non-empty text body.
  bool get hasMessage => widget.message.trim().isNotEmpty;

  /// Whether the message carries a non-empty media file.
  bool get hasFile => widget.file != null && widget.file!.isNotEmpty;

  /// Controller for an attached video; file-backed when local, cached
  /// otherwise.
  FlickManager? _flickManager;

  /// Sets up the video controller for the initial media source.
  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  /// Rebuilds the video controller when the logical video source changes —
  /// e.g. the media type changed, or the message flipped between a local
  /// file and a network URL — disposing the old file-backed controller first.
  @override
  void didUpdateWidget(SenderMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldIsLocalFile =
        oldWidget.isLocal ||
        (oldWidget.localPath != null &&
            File(oldWidget.localPath!).existsSync());
    final newIsLocalFile =
        widget.isLocal ||
        (widget.localPath != null && File(widget.localPath!).existsSync());

    final oldPath = oldWidget.localPath ?? oldWidget.file;
    final newPath = widget.localPath ?? widget.file;

    // If the logical video source (local or network) or media type changed
    if (oldWidget.mediaType != widget.mediaType ||
        oldIsLocalFile != newIsLocalFile ||
        (!newIsLocalFile && oldPath != newPath)) {
      if (_flickManager != null) {
        final controller =
            _flickManager!.flickVideoManager?.videoPlayerController;
        if (controller != null &&
            controller.dataSourceType == DataSourceType.file) {
          _flickManager?.dispose();
        }
        _flickManager = null;
      }
      _initializeVideo();
    }
  }

  /// Creates [_flickManager] for a video or reaction attachment.
  ///
  /// When the message is local (or a local file exists at [SenderMessageWidget.localPath])
  /// a per-message [VideoPlayerController.file] is used so the in-progress
  /// upload can be previewed; otherwise the shared network controller from
  /// [VideoControllerCache] is reused. The playback listener is attached so
  /// only one video plays at a time.
  void _initializeVideo() {
    if ((widget.mediaType == 'video' ||
            widget.mediaType == 'reaction' ||
            widget.messageType == 'reaction') &&
        hasFile) {
      final localFile =
          widget.localPath != null ? File(widget.localPath!) : null;
      final isLocalFileAvailable = localFile != null && localFile.existsSync();

      if (widget.isLocal || isLocalFileAvailable) {
        final videoSource = localFile ?? File(widget.file!);
        _flickManager = FlickManager(
          videoPlayerController: VideoPlayerController.file(videoSource),
          autoPlay: false,
        );
      } else {
        _flickManager = VideoControllerCache.getFlickManager(widget.file!);
      }

      _flickManager?.flickVideoManager?.videoPlayerController?.addListener(
        _videoListener,
      );
    }
  }

  /// Listener that pauses every other cached video when this one starts
  /// playing. Skipped for local files since they are not in the cache.
  /// Swallows "used after disposed" errors from controller races.
  void _videoListener() {
    final controller = _flickManager?.flickVideoManager?.videoPlayerController;
    if (controller == null) return;

    try {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        if (!widget.isLocal) {
          VideoControllerCache.pauseAllOtherVideos(widget.file!);
        }
      }
    } catch (_) {
      // Catch "used after disposed" errors in case of race conditions
    }
  }

  /// Detaches the playback listener and disposes the controller only when it
  /// is file-backed; cached network controllers are owned by
  /// [VideoControllerCache] and left intact.
  @override
  void dispose() {
    _flickManager?.flickVideoManager?.videoPlayerController?.removeListener(
      _videoListener,
    );
    final controller = _flickManager?.flickVideoManager?.videoPlayerController;
    if (controller != null &&
        controller.dataSourceType == DataSourceType.file) {
      _flickManager?.dispose();
    }
    super.dispose();
  }

  /// Builds the sent-message bubble: an animated highlight container wrapping
  /// a swipe-to-reply gesture, the optional quoted reply, the media (reaction
  /// bubble or image/video with upload overlay) and the text bubble.
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color:
            widget.isHighlighted
                ? AppColors.allPrimaryColor.withValues(alpha: 0.15)
                : Colors.transparent,
      ),
      child: SwipeTo(
        onLeftSwipe: (details) {
          widget.onReply();
        },
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: GestureDetector(
                // onLongPress: () {
                //   deleteReactionDialog(context);
                // },
                onLongPress: widget.onLongPressDelete,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.replyTo != null) _buildReplyToWidget(),
                    if (hasFile)
                      widget.messageType == 'reaction'
                          ? _buildReactionBubble()
                          : Padding(
                            padding: EdgeInsets.only(right: 3.w, bottom: 10.h),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: Stack(
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: 200.h,
                                    ),
                                    child:
                                        widget.mediaType == 'image'
                                            ? widget.isLocal
                                                ? Image.file(
                                                  File(widget.file!),
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                )
                                                : InboxCustomNetworkImage(
                                                  urls: widget.file!,
                                                  localPath: widget.localPath,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                )
                                            : _flickManager != null
                                            ? ValueListenableBuilder(
                                              valueListenable:
                                                  _flickManager!
                                                      .flickVideoManager!
                                                      .videoPlayerController!,
                                              builder: (context, value, child) {
                                                return AspectRatio(
                                                  aspectRatio:
                                                      value.isInitialized
                                                          ? value.aspectRatio
                                                          : 16 / 9,
                                                  child: FlickVideoPlayer(
                                                    key: ValueKey(
                                                      _flickManager,
                                                    ),
                                                    flickManager:
                                                        _flickManager!,
                                                    flickVideoWithControls:
                                                        const FlickVideoWithControls(
                                                          videoFit:
                                                              BoxFit.cover,
                                                          controls:
                                                              CustomFlickPortraitControls(),
                                                        ),
                                                  ),
                                                );
                                              },
                                            )
                                            : Container(
                                              height: 100.h,
                                              width: double.infinity,
                                              alignment: Alignment.center,
                                              child:
                                                  const CircularProgressIndicator(),
                                            ),
                                  ),
                                  if (widget.isLocal &&
                                      widget.uploadProgress != null &&
                                      widget.uploadProgress! < 1.0)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black54,
                                        child: Center(
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SizedBox(
                                                height: 40.sp,
                                                width: 40.sp,
                                                child:
                                                    CircularProgressIndicator(
                                                      value:
                                                          widget.uploadProgress,
                                                      color: Colors.white,
                                                      strokeWidth: 3.w,
                                                    ),
                                              ),
                                              Text(
                                                "${(widget.uploadProgress! * 100).toInt()}%",
                                                style: TextFontStyle
                                                    .headline12w400CFFFFFFPoppins
                                                    .copyWith(
                                                      fontSize: 11.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                    if (hasMessage)
                      Padding(
                        padding: EdgeInsets.only(right: 3.w),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.allPrimaryColor,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8.r),
                              bottomLeft: Radius.circular(8.r),
                              topRight: Radius.circular(8.r),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.message,
                                style: TextFontStyle
                                    .headline14w600C333333Poppins
                                    .copyWith(fontSize: 12.5.sp),
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.time ?? "",
                                    style: TextFontStyle
                                        .headline14w600C333333Poppins
                                        .copyWith(
                                          fontSize: 10.sp,
                                          color: Colors.black,
                                        ),
                                  ),
                                  UIHelper.horizontalSpace(4.w),
                                  widget.isLocal
                                      ? SizedBox(
                                        height: 8.sp,
                                        width: 8.sp,
                                        child: CircularProgressIndicator(
                                          color: AppColors.c000000,
                                          strokeWidth: 1.5.w,
                                        ),
                                      )
                                      : Icon(
                                        Icons.check_rounded,
                                        size: 12.sp,
                                        color: Colors.blueAccent,
                                      ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the bubble for an outgoing reaction message — a labelled
  /// "Reaction" header above the reaction video (with an upload-progress
  /// overlay while local) and a timestamp with a sent indicator.
  Widget _buildReactionBubble() {
    // final replyTo = widget.replyTo;

    return Padding(
      padding: EdgeInsets.only(right: 3.w, bottom: 10.h),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2E1A),
          borderRadius: BorderRadius.circular(12.r),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Reaction label + video ────────────────────────
            Padding(
              padding: EdgeInsets.all(6.sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_rounded,
                        size: 12.sp,
                        color: AppColors.allPrimaryColor,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        "Reaction",
                        style: TextFontStyle.headline12w400CFFFFFFPoppins
                            .copyWith(
                              fontSize: 10.sp,
                              color: AppColors.allPrimaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),

                  // ── Video player with upload progress overlay ─
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Stack(
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 200.h),
                          child:
                              _flickManager != null
                                  ? ValueListenableBuilder(
                                    valueListenable:
                                        _flickManager!
                                            .flickVideoManager!
                                            .videoPlayerController!,
                                    builder: (context, value, child) {
                                      return AspectRatio(
                                        aspectRatio:
                                            value.isInitialized
                                                ? value.aspectRatio
                                                : 16 / 9,
                                        child: FlickVideoPlayer(
                                          key: ValueKey(_flickManager),
                                          flickManager: _flickManager!,
                                          flickVideoWithControls:
                                              const FlickVideoWithControls(
                                                videoFit: BoxFit.cover,
                                                controls:
                                                    CustomFlickPortraitControls(),
                                              ),
                                        ),
                                      );
                                    },
                                  )
                                  : Container(
                                    height: 100.h,
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    child: const CircularProgressIndicator(),
                                  ),
                        ),

                        // Upload progress overlay
                        if (widget.isLocal &&
                            widget.uploadProgress != null &&
                            widget.uploadProgress! < 1.0)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black54,
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      height: 40.sp,
                                      width: 40.sp,
                                      child: CircularProgressIndicator(
                                        value: widget.uploadProgress,
                                        color: Colors.white,
                                        strokeWidth: 3.w,
                                      ),
                                    ),
                                    Text(
                                      "${(widget.uploadProgress! * 100).toInt()}%",
                                      style: TextFontStyle
                                          .headline12w400CFFFFFFPoppins
                                          .copyWith(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: 4.h),
                  // ── Timestamp + sent indicator ────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.time ?? "",
                        style: TextFontStyle.headline14w600C333333Poppins
                            .copyWith(fontSize: 9.sp, color: Colors.white54),
                      ),
                      SizedBox(width: 4.w),
                      widget.isLocal
                          ? SizedBox(
                            height: 8.sp,
                            width: 8.sp,
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 1.5.w,
                            ),
                          )
                          : Icon(
                            Icons.check_rounded,
                            size: 12.sp,
                            color: Colors.blueAccent,
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the quoted-reply preview shown above the bubble, with the
  /// original sender's name, text and an optional (possibly blurred) media
  /// thumbnail. Tapping it invokes [SenderMessageWidget.onTapReply] to jump
  /// to the original message; returns an empty box when there is no reply.
  Widget _buildReplyToWidget() {
    final replyTo = widget.replyTo;
    if (replyTo == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(right: 3.w, bottom: 4.h),
      child: GestureDetector(
        onTap: () {
          if (replyTo.id != null) {
            widget.onTapReply?.call(replyTo.id!);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8.r),
            border: Border(
              right: BorderSide(color: AppColors.allPrimaryColor, width: 3.w),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                replyTo.sender?.firstName ?? "",
                style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.allPrimaryColor,
                  fontSize: 11.sp,
                ),
              ),
              SizedBox(height: 2.h),
              if (replyTo.text != null && replyTo.text!.isNotEmpty)
                Text(
                  replyTo.text!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
                    fontSize: 10.sp,
                    color: Colors.white70,
                  ),
                ),
              if (replyTo.file != null && replyTo.file!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 70.h,
                        maxWidth: 120,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          (replyTo.isBlurred == 1 ||
                                  replyTo.isBlurred == true ||
                                  replyTo.isBlurred == '1' ||
                                  replyTo.isBlurred == 'true')
                              ? ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 8,
                                  sigmaY: 8,
                                ),
                                child: InboxCustomNetworkImage(
                                  urls: replyTo.file!,
                                  fit: BoxFit.cover,
                                ),
                              )
                              : InboxCustomNetworkImage(
                                urls: replyTo.file!,
                                fit: BoxFit.cover,
                              ),
                          if (replyTo.mediaType == 'video')
                            Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 24.sp,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
