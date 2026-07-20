import 'dart:io';

import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:video_player/video_player.dart';

import '../../../../common_widget/inbox_custom_network_image.dart';
import '../../../../constants/text_font_style.dart';
import '../../../../helpers/video_controller_cache.dart';
import 'custom_video_controls.dart';
import '../full_screen_image_viewer.dart';
import 'forwarded_label.dart';
import 'message_status_ticks.dart';
import 'sender_reply_quote.dart';
import 'sender_text_bubble.dart';

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
  /// [onLongPress] opens the message action menu at the press position,
  /// [onReply] handles swipe-to-reply, and [replyTo]/[onTapReply] drive the
  /// quoted preview.
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
    required this.onLongPress,
    required this.onReply,
    this.isLocal = false,
    this.localPath,
    this.uploadProgress,
    this.replyTo,
    this.onTapReply,
    this.messageType,
    this.isBlur,
    this.isHighlighted = false,
    this.isSeen = false,
    this.readReceiptsEnabled = true,
    this.isEdited = false,
    this.isForwarded = false,
  });

  /// Whether the sender has edited this message (shows an "edited" label).
  final bool isEdited;

  /// Whether this message was forwarded (shows a "Forwarded" label above it).
  final bool isForwarded;

  /// Whether the recipient has seen this message. Drives the text double-check
  /// and the reaction "watched" dot; ignored for plain media bubbles.
  final bool isSeen;

  /// Whether the local user keeps read receipts on; when off, "seen" state is
  /// never rendered (reciprocal).
  final bool readReceiptsEnabled;

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

  /// Invoked on long-press with the global press position, so the parent can
  /// open the message action menu anchored there.
  final void Function(Offset globalPosition) onLongPress;

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

  /// Whether [SenderMessageWidget.file] is a remote (http) URL rather than a
  /// local filesystem path.
  ///
  /// A just-sent image keeps a local path in `file` until the server URL
  /// replaces it. The image source must therefore be chosen by the path's
  /// nature, not by [SenderMessageWidget.isLocal] — that flag flips to false on
  /// send success *before* the server URL is known, and rendering a local path
  /// through a network image loader made sent photos vanish (the loader fails
  /// the bogus "URL" and shows the error placeholder) until a re-fetch supplied
  /// the real URL.
  bool get _fileIsRemote =>
      widget.file != null && widget.file!.startsWith('http');

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
                onLongPressStart:
                    (details) => widget.onLongPress(details.globalPosition),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.isForwarded)
                      ForwardedLabel(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    if (widget.replyTo != null)
                      SenderReplyQuote(
                        replyTo: widget.replyTo,
                        onTapReply: widget.onTapReply,
                      ),
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
                                            ? !_fileIsRemote
                                                ? Image.file(
                                                  File(widget.file!),
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                )
                                                : GestureDetector(
                                                  onTap:
                                                      () => Navigator.of(
                                                        context,
                                                      ).push(
                                                        MaterialPageRoute(
                                                          builder:
                                                              (
                                                                _,
                                                              ) => FullScreenImageViewer(
                                                                url:
                                                                    widget
                                                                        .file!,
                                                              ),
                                                        ),
                                                      ),
                                                  child:
                                                      InboxCustomNetworkImage(
                                                        urls: widget.file!,
                                                        localPath:
                                                            widget.localPath,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                      ),
                                                )
                                            : _flickManager != null
                                            ? ValueListenableBuilder(
                                              valueListenable:
                                                  _flickManager!
                                                      .flickVideoManager!
                                                      .videoPlayerController!,
                                              builder: (context, value, child) {
                                                return RepaintBoundary(
                                                  child: AspectRatio(
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
                      SenderTextBubble(
                        message: widget.message,
                        time: widget.time,
                        isLocal: widget.isLocal,
                        isSeen: widget.isSeen,
                        readReceiptsEnabled: widget.readReceiptsEnabled,
                        isEdited: widget.isEdited,
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
                  // ── Timestamp + reaction "watched" dot ────────
                  // The reaction is the app's only "did they see my reaction"
                  // signal: a quiet grey→green dot once the recipient watches
                  // it (a spinner while the reaction is still uploading).
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
                          ? MessageStatusTicks(
                            status: MessageTickStatus.sending,
                            spinnerColor: Colors.white54,
                            size: 11,
                          )
                          : ReactionSeenDot(
                            seen: widget.isSeen && widget.readReceiptsEnabled,
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
}
