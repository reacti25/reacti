// ignore_for_file: must_be_immutable

import 'dart:developer';

import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:swipe_to/swipe_to.dart';

import '../../../../analytics/analytics_locator.dart';
import '../../../../analytics/events.dart';
import '../../../../analytics/media_authenticity.dart';
import '../../../../common_widget/avatar_circle.dart';
import '../../../../common_widget/inbox_custom_network_image.dart';
import '../../../../helpers/video_controller_cache.dart';
import '../../../../networks/api_access.dart';
import '../../data/reaction_recorder/recorder.dart';
import 'custom_video_controls.dart';
import 'receiver_reply_quote.dart';
import 'receiver_text_bubble.dart';

/// Chat bubble for an incoming (received) message in a one-to-one or group
/// conversation.
///
/// Renders the peer avatar, optional quoted reply, text and media. Media
/// (image/video/reaction) arrives blurred and is unblurred on tap.
///
/// This widget is the entry point for the patent-protected reaction flow:
/// when the recipient taps a blurred media placeholder, the `mark-viewed`
/// API is called, and on success the front camera is silently recorded and
/// the clip is uploaded back as a `type: "reaction"` message. See
/// [_buildBlurPlaceholder] and [recordVideoSilently].
///
/// Used by [InboxScreen] and [GroupInboxScreen] for messages whose sender is
/// not the current user.
class ReceiverMessageWidget extends StatefulWidget {
  /// Creates a received-message bubble.
  ///
  /// [message] is the text body and [avatar] the peer avatar URL. [file] and
  /// [fileType] describe an optional attachment, and [isBlurred] is the
  /// initial blur state of that media. [messageId] identifies the message
  /// for the `mark-viewed` call. [userId] (one-to-one) or [groupId] plus
  /// [isGroup] route the reaction upload. The `onReaction*` callbacks let the
  /// parent show an optimistic reaction message and track its upload, while
  /// [onUnblur] notifies the parent that the media is now revealed.
  /// [onReply] handles swipe-to-reply, [replyTo]/[onTapReply] drive the
  /// quoted-reply preview, and [isHighlighted] tints the bubble when it is
  /// the target of a reply jump.
  ReceiverMessageWidget({
    super.key,
    required this.message,
    required this.avatar,
    this.firstName,
    this.lastName,
    this.time,
    this.file,
    this.fileType,
    required this.isBlurred,
    required this.messageId,
    this.userId,
    this.isGroup = false,
    this.groupId,
    this.onReactionSend,
    this.onReactionProgress,
    this.onReactionSuccess,
    required this.onUnblur,
    required this.onReply,
    this.replyTo,
    this.onTapReply,
    this.messageType,
    this.isHighlighted = false,
  });

  /// Whether the bubble is the current target of a reply jump (tinted).
  final bool isHighlighted;

  /// The quoted message this bubble replies to; loosely typed since it may be
  /// a one-to-one or group `ReplyTo` model.
  final dynamic replyTo;

  /// Invoked with a message id when the quoted-reply preview is tapped.
  final Function(int)? onTapReply;

  /// Server-side message kind; `reaction` selects the reaction bubble layout.
  final String? messageType;

  /// Text body of the received message.
  final String message;

  /// Avatar image URL of the message's sender.
  final String avatar;

  /// Sender's first name, used for the initials fallback when [avatar] is empty.
  final String? firstName;

  /// Sender's last name, used for the initials fallback when [avatar] is empty.
  final String? lastName;

  /// Human-readable timestamp shown beneath the message.
  final String? time;

  /// URL of the attached media file, if any.
  final String? file;

  /// Media kind of [file] (`image`, `video`, `reaction`).
  final String? fileType;

  /// Initial blur state of the media; kept mutable so the parent can sync it.
  bool isBlurred;

  /// Identifier of this message, passed to the `mark-viewed` API.
  final int? messageId;

  /// Identifier of the peer user, used to route a one-to-one reaction upload.
  final int? userId;

  /// Whether this bubble belongs to a group conversation.
  final bool isGroup;

  /// Identifier of the group, used to route a group reaction upload.
  final int? groupId;

  /// Called when a reaction recording starts, so the parent can insert an
  /// optimistic local message keyed by `tempId`.
  final Function(int tempId, XFile file)? onReactionSend;

  /// Called repeatedly with the reaction upload progress (0.0–1.0).
  final Function(int tempId, double progress)? onReactionProgress;

  /// Called when the reaction upload finishes, reporting success or failure.
  final Function(int tempId, bool success)? onReactionSuccess;

  /// Notifies the parent that the media has been unblurred (revealed).
  final VoidCallback onUnblur; // ✅ Callback to parent

  /// Invoked on swipe-to-reply so the parent can stage a reply to this bubble.
  final VoidCallback onReply; // ✅ Callback to handle swipe-to-reply

  /// Creates the mutable state that drives blur and video playback.
  @override
  State<ReceiverMessageWidget> createState() => _ReceiverMessageWidgetState();
}

/// State for [ReceiverMessageWidget].
///
/// Holds the local blur flag and the video controller. Kept alive
/// ([wantKeepAlive]) so scrolling away and back does not re-trigger blur or
/// rebuild the video controller.
class _ReceiverMessageWidgetState extends State<ReceiverMessageWidget>
    with AutomaticKeepAliveClientMixin {
  /// Keeps this list item alive while off-screen to preserve playback/blur.
  @override
  bool get wantKeepAlive => true;

  /// Whether the message carries a non-empty text body.
  bool get hasMessage => widget.message.trim().isNotEmpty;

  /// Whether the message carries a non-empty media file.
  bool get hasFile => widget.file != null && widget.file!.isNotEmpty;

  /// Local blur state; starts blurred and is cleared once the media is viewed.
  bool _isBlurred = true;

  /// Controller for an attached video, sourced from [VideoControllerCache].
  FlickManager? _flickManager;

  // --- Patent authenticity / media-UX timing (fire-and-forget; never alters
  // the flow). All nullable until the corresponding moment occurs. ---

  /// When the media was unblurred (exposure window start). Null until viewed.
  DateTime? _unblurAt;

  /// When the media first decoded / showed its first frame. Null until visible.
  DateTime? _mediaVisibleAt;

  /// When the silent recording began, and how long it ran.
  DateTime? _recordStartAt;
  Duration? _recordingDuration;

  /// Pending image-decode probe (resolves the same cached image the visible
  /// widget uses, to time decode without touching the render widget); cleared
  /// once it fires or on dispose.
  ImageStream? _mediaImageStream;
  ImageStreamListener? _mediaImageListener;

  /// One-shot listener that detects the video's first initialized frame.
  VoidCallback? _mediaVideoListener;

  /// Initializes local blur state and, for video attachments, acquires a
  /// cached [FlickManager] and attaches the playback listener.
  @override
  void initState() {
    super.initState();
    // Initialize local blur state from widget
    _isBlurred = widget.isBlurred;
    if (widget.fileType == "video" && widget.file != null) {
      if (widget.fileType == 'video' && hasFile) {
        _flickManager = VideoControllerCache.getFlickManager(widget.file!);
      }

      _flickManager?.flickVideoManager?.videoPlayerController?.addListener(
        _videoListener,
      );
    }
  }

  /// Re-syncs [_isBlurred] from the widget when the parent rebuilds this
  /// bubble with a changed [ReceiverMessageWidget.isBlurred].
  @override
  void didUpdateWidget(covariant ReceiverMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync local blur state when the parent rebuilds with updated isBlurred
    if (oldWidget.isBlurred != widget.isBlurred) {
      _isBlurred = widget.isBlurred;
    }
  }

  /// Listener attached to the video controller that pauses every other
  /// cached video whenever this one starts playing, so only one plays at a
  /// time. Swallows "used after disposed" errors from controller races.
  void _videoListener() {
    final controller = _flickManager?.flickVideoManager?.videoPlayerController;
    if (controller == null) return;

    try {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        VideoControllerCache.pauseAllOtherVideos(widget.file!);
      }
    } catch (_) {
      // Catch "used after disposed" errors in case of race conditions
    }
  }

  /// Detaches the playback listener. The [FlickManager] itself is owned by
  /// [VideoControllerCache] and is intentionally not disposed here.
  @override
  void dispose() {
    // Close the exposure window and emit authenticity metrics before tearing
    // down (fire-and-forget; never throws into dispose).
    _emitExposureMetrics();
    _stopMediaVisibilityWatch();
    _flickManager?.flickVideoManager?.videoPlayerController?.removeListener(
      _videoListener,
    );
    super.dispose();
  }

  /// Records the silent 4-second front-camera reaction. Delegates to
  /// the global [reactionRecorder] so the camera dependency can be
  /// swapped out in tests (see
  /// `app/test/features/chat/widget/patent_flow_interactive_test.dart`).
  /// Behaviour is identical to the previous inline implementation.
  Future<XFile?> recordVideoSilently() => reactionRecorder.record();

  /// Analytics scope for this bubble's conversation kind.
  String get _scope => widget.isGroup ? 'group' : 'private';

  /// Records the silent-capture outcome (metadata only — never the clip).
  /// Fire-and-forget; never affects the patent flow.
  void _trackReactionRecorded({required bool captured, required int recordMs}) {
    try {
      analytics.track(Events.reactionRecorded, {
        Props.scope: _scope,
        Props.recordMs: recordMs,
        Props.result: captured ? 'success' : 'failure',
        if (!captured) Props.failureReason: 'null_clip',
      });
    } catch (_) {
      // Analytics must never disrupt the reaction flow.
    }
  }

  /// Records the mark-viewed -> reaction-uploaded latency. Fire-and-forget.
  void _trackMarkViewedToReaction(DateTime markViewedAt) {
    try {
      analytics.track(Events.markViewedToReaction, {
        Props.scope: _scope,
        Props.elapsedMs: DateTime.now().difference(markViewedAt).inMilliseconds,
      });
    } catch (_) {
      // Analytics must never disrupt the reaction flow.
    }
  }

  /// Coarse media kind for analytics: `image` for images, otherwise `video`
  /// (videos and reaction clips are both video).
  String get _mediaKind => widget.fileType == 'image' ? 'image' : 'video';

  /// Fire-and-forget analytics emit that can never disrupt the patent flow.
  void _safeTrack(String event, Map<String, Object?> props) {
    try {
      analytics.track(event, props);
    } catch (_) {
      // Analytics must never disrupt the reaction flow.
    }
  }

  /// Starts watching for the moment the unblurred media becomes visible
  /// (image decoded / video first frame) so [media_load_ms] and the exposure
  /// window can be measured. Best-effort and purely observational.
  void _beginMediaVisibilityWatch() {
    try {
      if (widget.fileType == 'image') {
        _watchImageDecode();
      } else {
        _watchVideoFirstFrame();
      }
    } catch (_) {
      // Never let instrumentation touch the flow.
    }
  }

  /// Resolves the same cached image the visible widget shows and records when
  /// it finishes decoding — without modifying the render widget.
  void _watchImageDecode() {
    final url = widget.file;
    if (url == null || url.isEmpty) return;
    final stream = CachedNetworkImageProvider(
      url,
    ).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (image, _) => _onMediaVisible(success: true),
      onError: (_, _) => _onMediaVisible(success: false),
    );
    _mediaImageStream = stream;
    _mediaImageListener = listener;
    stream.addListener(listener);
  }

  /// Records when the cached video controller reports its first initialized
  /// frame (or immediately if it is already initialized).
  void _watchVideoFirstFrame() {
    final controller = _flickManager?.flickVideoManager?.videoPlayerController;
    if (controller == null) return;
    if (controller.value.isInitialized) {
      _onMediaVisible(success: true);
      return;
    }
    void listener() {
      final c = _flickManager?.flickVideoManager?.videoPlayerController;
      if (c != null && c.value.isInitialized) {
        c.removeListener(_mediaVideoListener!);
        _mediaVideoListener = null;
        _onMediaVisible(success: true);
      }
    }

    _mediaVideoListener = listener;
    controller.addListener(listener);
  }

  /// Marks the media as visible (once) and emits `media_loaded`.
  void _onMediaVisible({required bool success}) {
    if (_mediaVisibleAt != null) return; // first transition only
    final unblurAt = _unblurAt;
    if (unblurAt == null) return;
    _mediaVisibleAt = DateTime.now();
    _safeTrack(Events.mediaLoaded, {
      Props.scope: _scope,
      Props.mediaKind: _mediaKind,
      Props.mediaLoadMs: _mediaVisibleAt!.difference(unblurAt).inMilliseconds,
      Props.result: success ? 'success' : 'failure',
    });
  }

  /// Detaches any pending media-visibility probes (image stream / video
  /// listener). Safe to call when none are active.
  void _stopMediaVisibilityWatch() {
    final stream = _mediaImageStream;
    final imageListener = _mediaImageListener;
    if (stream != null && imageListener != null) {
      stream.removeListener(imageListener);
    }
    _mediaImageStream = null;
    _mediaImageListener = null;

    final videoListener = _mediaVideoListener;
    if (videoListener != null) {
      _flickManager?.flickVideoManager?.videoPlayerController?.removeListener(
        videoListener,
      );
      _mediaVideoListener = null;
    }
  }

  /// On dispose, closes the exposure window and emits `media_exposure` plus —
  /// when a recording happened — the `recording_media_overlap` authenticity
  /// metric. No-op if the media was never viewed.
  void _emitExposureMetrics() {
    final unblurAt = _unblurAt;
    if (unblurAt == null) return; // never viewed — nothing to report

    // Exposure window starts when the media became visible (falls back to the
    // unblur instant if decode/first-frame was not observed).
    final exposureStart = _mediaVisibleAt ?? unblurAt;
    final exposureMs = DateTime.now().difference(exposureStart).inMilliseconds;

    _safeTrack(Events.mediaExposure, {
      Props.scope: _scope,
      Props.mediaKind: _mediaKind,
      Props.mediaExposureMs: exposureMs,
    });

    final recordStartAt = _recordStartAt;
    final recordingDuration = _recordingDuration;
    if (recordStartAt == null || recordingDuration == null) return;

    final overlap = MediaAuthenticity.compute(
      recordingStartOffsetMs:
          recordStartAt.difference(exposureStart).inMilliseconds,
      recordingDurationMs: recordingDuration.inMilliseconds,
      mediaExposureMs: exposureMs,
    );
    _safeTrack(Events.recordingMediaOverlap, {
      Props.scope: _scope,
      Props.overlapMs: overlap.overlapMs,
      Props.overlapPct: overlap.overlapPct,
      Props.recordingStartOffsetMs: overlap.recordingStartOffsetMs,
      Props.recordingDurationMs: overlap.recordingDurationMs,
      Props.mediaExposureMs: overlap.mediaExposureMs,
    });
  }

  /// Builds the received-message bubble: an animated highlight container
  /// wrapping a swipe-to-reply gesture, the quoted reply (if any), the text
  /// bubble, the media preview and the overlaid sender avatar.
  @override
  Widget build(BuildContext context) {
    log("Is blur ======> ${widget.isBlurred}");
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
        onRightSwipe: (details) {
          widget.onReply();
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  /// 🟢 Message + File bubble
                  Padding(
                    padding: EdgeInsets.only(left: 38.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.replyTo != null)
                          ReceiverReplyQuote(
                            replyTo: widget.replyTo,
                            onTapReply: widget.onTapReply,
                          ),
                        if (hasMessage)
                          ReceiverTextBubble(
                            message: widget.message,
                            time: widget.time,
                            hasFile: hasFile,
                          ),
                        if (hasFile)
                          _buildFilePreview(context, widget.file ?? ""),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: AvatarCircle(
                      url: widget.avatar,
                      firstName: widget.firstName,
                      lastName: widget.lastName,
                      size: 24.w,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Chooses the media widget for the bubble.
  ///
  /// Reaction messages always use the reaction bubble. Otherwise, blurred
  /// image/video/reaction media shows the tappable blur placeholder, and
  /// unblurred media shows the image or video player. [file] is the media
  /// URL; returns an empty box when nothing matches.
  Widget _buildFilePreview(BuildContext context, String file) {
    if (widget.messageType == 'reaction') {
      return _buildReactionBubble();
    }

    if (_isBlurred &&
        (widget.fileType == 'image' ||
            widget.fileType == 'video' ||
            widget.fileType == 'reaction' ||
            widget.messageType == 'reaction')) {
      return _buildBlurPlaceholder();
    }

    if (widget.fileType == 'image') {
      return _buildImageMedia();
    } else if (widget.fileType == 'video' ||
        widget.fileType == 'reaction' ||
        widget.messageType == 'reaction') {
      return _buildVideoMedia();
    }
    return const SizedBox.shrink();
  }

  /// Builds the bubble for a reaction message — a labelled "Reaction" header
  /// above either the blur placeholder or the reaction video, plus a
  /// timestamp. The commented-out block is a previously explored quoted
  /// "original message" preview that is intentionally disabled.
  Widget _buildReactionBubble() {
    // final replyTo = widget.replyTo;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E0A),
        borderRadius: BorderRadius.circular(12.r),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Quoted original message ──────────────────────────────
          // if (replyTo != null)
          //   GestureDetector(
          //     onTap: () {
          //       if (replyTo.id != null) {
          //         widget.onTapReply?.call(replyTo.id!);
          //       }
          //     },
          //     child: Container(
          //       width: double.infinity,
          //       padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          //       decoration: BoxDecoration(
          //         color: Colors.white.withValues(alpha: 0.08),
          //         border: Border(
          //           left: BorderSide(
          //             color: AppColors.allPrimaryColor,
          //             width: 3.w,
          //           ),
          //         ),
          //       ),
          //       child: Column(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           Text(
          //             replyTo.sender?.firstName ?? "",
          //             style: TextFontStyle.headline12w400CFFFFFFPoppins
          //                 .copyWith(
          //                   fontWeight: FontWeight.bold,
          //                   color: AppColors.allPrimaryColor,
          //                   fontSize: 11.sp,
          //                 ),
          //           ),
          //           SizedBox(height: 2.h),
          //           // Original text
          //           if (replyTo.text != null && replyTo.text!.isNotEmpty)
          //             Text(
          //               replyTo.text!,
          //               maxLines: 2,
          //               overflow: TextOverflow.ellipsis,
          //               style: TextFontStyle.headline12w400CFFFFFFPoppins
          //                   .copyWith(fontSize: 10.sp, color: Colors.white70),
          //             ),
          //           // Original media thumbnail
          //           if (replyTo.file != null && replyTo.file!.isNotEmpty)
          //             Padding(
          //               padding: EdgeInsets.only(top: 4.h),
          //               child: ClipRRect(
          //                 borderRadius: BorderRadius.circular(4.r),
          //                 child: ConstrainedBox(
          //                   constraints: BoxConstraints(maxHeight: 50.h),
          //                   child:
          //                       (replyTo.isBlurred == 1 ||
          //                               replyTo.isBlurred == true)
          //                           ? ImageFiltered(
          //                             imageFilter: ImageFilter.blur(
          //                               sigmaX: 8,
          //                               sigmaY: 8,
          //                             ),
          //                             child: InboxCustomNetworkImage(
          //                               urls: replyTo.file!,
          //                               fit: BoxFit.cover,
          //                             ),
          //                           )
          //                           : InboxCustomNetworkImage(
          //                             urls: replyTo.file!,
          //                             fit: BoxFit.cover,
          //                           ),
          //                 ),
          //               ),
          //             ),
          //         ],
          //       ),
          //     ),
          //   ),

          // ── Reaction video ───────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(6.sp),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
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
                // The actual video / blur placeholder
                _isBlurred ? _buildBlurPlaceholder() : _buildVideoMedia(),
                // Timestamp
                SizedBox(height: 4.h),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    widget.time ?? "",
                    style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
                      fontSize: 9.sp,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the unblurred image preview, constrained to a maximum height.
  Widget _buildImageMedia() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 200.h),
        child: InboxCustomNetworkImage(
          urls: widget.file ?? "",
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// Builds the unblurred video player using the cached [_flickManager];
  /// shows a spinner until the controller is ready.
  Widget _buildVideoMedia() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white54),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child:
            _flickManager != null
                ? ValueListenableBuilder(
                  valueListenable:
                      _flickManager!.flickVideoManager!.videoPlayerController!,
                  builder: (context, value, child) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 200.h),
                      child: FlickVideoPlayer(
                        key: ValueKey(_flickManager),
                        flickManager: _flickManager!,
                        flickVideoWithControls: const FlickVideoWithControls(
                          videoFit: BoxFit.cover,
                          controls: CustomFlickPortraitControls(),
                        ),
                      ),
                    );
                  },
                )
                : const CircularProgressIndicator(),
      ),
    );
  }

  /// Builds the tappable "Click to view the media" placeholder shown over
  /// blurred media — and the heart of the patent-protected reaction flow.
  ///
  /// On tap (only while [_isBlurred]):
  /// 1. Calls the `mark-viewed` API — `viewInboxImage` for one-to-one chats
  ///    or `viewGroupFile` for groups — keyed by [ReceiverMessageWidget.messageId].
  /// 2. On success, clears [_isBlurred] (blur → unblur transition) and calls
  ///    [ReceiverMessageWidget.onUnblur] so the parent updates its state.
  /// 3. Silently records the front camera via [recordVideoSilently].
  /// 4. If a clip was captured, uploads it as a `type: "reaction"` message
  ///    that replies to the viewed message: `sendGroupMessageRx` for groups
  ///    (with progress and lifecycle callbacks) or `sendMessageRx` for
  ///    one-to-one chats.
  ///
  /// Note: the inner `if (widget.isGroup)` branches are reached only when the
  /// outer condition selected the matching `mark-viewed` endpoint, so the
  /// recording and upload always target the correct conversation.
  Widget _buildBlurPlaceholder() {
    return InkWell(
      onTap: () {
        if (!_isBlurred) {
          return;
        }

        // Guard the ids the flow used to force-unwrap (messageId! / userId! /
        // groupId!): an optimistic or malformed realtime message can carry a
        // null id, which previously threw an uncaught TypeError inside the
        // async chain. Without a message id there is nothing to mark viewed,
        // so the tap is a no-op.
        final messageId = widget.messageId;
        if (messageId == null) {
          return;
        }

        // Single path for both conversation kinds — pick the mark-viewed
        // endpoint from isGroup once (previously this was two ~70-line copies,
        // each with a dead inner isGroup branch).
        final markViewed =
            widget.isGroup
                ? viewGroupFileRx.viewGroupFile(id: messageId)
                : viewInboxImageRx.viewInboxImage(id: messageId);

        markViewed.waitingForSuccess().then((value) async {
          if (!value) {
            // mark-viewed failed: the media stays blurred and the placeholder
            // is still tappable, so the user can retry. Log it so the failure
            // is observable instead of a silent no-op.
            log("Reaction flow: mark-viewed failed; media stays blurred");
            return;
          }

          // Drop the blur overlay as soon as the view is recorded, and notify
          // the parent to update its state.
          setState(() {
            _isBlurred = false;
          });
          widget.onUnblur();

          // Start of the mark-viewed -> reaction-uploaded latency window
          // (analytics only — does not affect the flow).
          final markViewedAt = DateTime.now();

          // Authenticity instrumentation (analytics only): the unblur is the
          // exposure-window start; begin watching for the media becoming
          // visible. Both are observational and never alter the flow below.
          _unblurAt = markViewedAt;
          _beginMediaVisibilityWatch();

          // Patent flow: silently capture the viewer's reaction.
          final recordStopwatch = Stopwatch()..start();
          _recordStartAt = DateTime.now();
          final videoFile = await recordVideoSilently();
          recordStopwatch.stop();
          _recordingDuration = recordStopwatch.elapsed;
          _trackReactionRecorded(
            captured: videoFile != null,
            recordMs: recordStopwatch.elapsedMilliseconds,
          );
          if (videoFile == null) {
            // Capture failed (no camera, permission denied, or the plugin
            // returned null). The media is shown but no reaction is sent — log
            // it so the capture-failure rate is observable.
            log(
              "Reaction flow: recordVideoSilently returned null; no reaction sent",
            );
            return;
          }

          // Temporary id for the optimistic local reaction entry.
          final tempId = DateTime.now().millisecondsSinceEpoch;

          if (widget.isGroup) {
            final groupId = widget.groupId;
            if (groupId == null) {
              return;
            }
            widget.onReactionSend?.call(tempId, videoFile);
            sendGroupMessageRx
                .sendMessage(
                  id: groupId,
                  file: videoFile,
                  type: "reaction",
                  replyToId: messageId,
                  onSendProgress: (sent, total) {
                    if (total != -1) {
                      widget.onReactionProgress?.call(tempId, sent / total);
                    }
                  },
                )
                .then((success) {
                  widget.onReactionSuccess?.call(tempId, success);
                  if (success) {
                    log("Group reaction video sent successfully");
                  }
                  _trackMarkViewedToReaction(markViewedAt);
                });
          } else {
            final userId = widget.userId;
            if (userId == null) {
              return;
            }
            sendMessageRx
                .sendMessage(
                  id: userId,
                  file: videoFile,
                  type: "reaction",
                  replyToId: messageId,
                )
                .then((success) {
                  if (success) {
                    log("Reaction video sent successfully");
                  }
                  _trackMarkViewedToReaction(markViewedAt);
                });
          }
        });
      },
      child: Container(
        padding: EdgeInsets.all(12.sp),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white30),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          spacing: 12.sp,
          children: [
            SvgPicture.asset(Assets.icons.appLogo),
            Text(
              "Click to view the media",
              style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
                fontSize: 12.sp,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
