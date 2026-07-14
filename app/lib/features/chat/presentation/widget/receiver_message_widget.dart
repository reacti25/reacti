// ignore_for_file: must_be_immutable

import 'dart:async';
import 'dart:developer';

import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/theme/app_theme.dart';
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
import '../../../../analytics/media_timeline.dart';
import '../../../../helpers/feature_flags.dart';
import '../../../../common_widget/avatar_circle.dart';
import '../../../../common_widget/inbox_custom_network_image.dart';
import '../../../../helpers/network_status.dart';
import '../../../../helpers/video_controller_cache.dart';
import '../../../../networks/api_access.dart';
import '../../data/reaction_recorder/recorder.dart';
import '../../data/reaction_watched_api.dart';
import '../../logic/playback_start_detector.dart';
import '../../logic/video_watch_window.dart';
import '../full_screen_image_viewer.dart';
import 'custom_video_controls.dart';
import 'forwarded_label.dart';
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
    required this.onLongPress,
    this.replyTo,
    this.onTapReply,
    this.messageType,
    this.isHighlighted = false,
    this.isEdited = false,
    this.isForwarded = false,
  });

  /// Whether the sender has edited this message (shows an "edited" label).
  final bool isEdited;

  /// Whether this message was forwarded (shows a "Forwarded" label above it).
  final bool isForwarded;

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
  final Function(int tempId, bool success, int? serverId)? onReactionSuccess;

  /// Notifies the parent that the media has been unblurred (revealed).
  final VoidCallback onUnblur; // ✅ Callback to parent

  /// Invoked on swipe-to-reply so the parent can stage a reply to this bubble.
  final VoidCallback onReply; // ✅ Callback to handle swipe-to-reply

  /// Invoked on long-press with the global press position, so the parent can
  /// open the message action menu anchored there. Coexists with the blur tap
  /// (a tap, not a long-press) so the patented reveal flow is untouched.
  final void Function(Offset globalPosition) onLongPress;

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

  /// When the blurred placeholder was tapped — the open-timeline origin (t=0).
  /// Null until the media is tapped.
  DateTime? _tapAt;

  /// When the media was unblurred (exposure window start). Null until viewed.
  DateTime? _unblurAt;

  /// When the media first decoded / showed its first frame. Null until visible.
  DateTime? _mediaVisibleAt;

  /// When the ready media first painted a frame (post-frame after visible) —
  /// the moment the Phase-1 trigger re-anchor will fire on. Null until painted.
  DateTime? _mediaPaintedAt;

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

  /// One-shot listener that starts playback once the just-unblurred video is
  /// initialized (see [_playVideoOnUnblur]). Cleared once it fires or on dispose.
  VoidCallback? _autoplayListener;

  // --- Phase-1 trigger re-anchor (flag `reaction_trigger_on_paint`). When the
  // flag is on, the silent recording starts on the first painted frame (or a
  // fallback timeout) instead of immediately after mark-viewed, so the captured
  // reaction overlaps the media actually being on screen. Off by default →
  // current behaviour (record immediately). ---

  /// Whether the paint-anchored trigger is active for this view (flag read once
  /// at unblur). False → record fires immediately as before.
  bool _triggerOnPaint = false;

  /// Guards [_fireReactionCapture] so the recording starts exactly once,
  /// whichever of painted / timeout / immediate wins.
  bool _recordingFired = false;

  /// Fallback so the trigger never hangs if the first frame never paints
  /// (documented iOS black/late-first-frame bugs). Cancelled once fired.
  Timer? _triggerTimeout;

  /// Max wait from unblur to forced capture when painted never arrives.
  static const Duration _paintTriggerTimeout = Duration(milliseconds: 2500);

  /// mark-viewed id + instant, stashed at unblur so the deferred paint/timeout
  /// trigger can run the capture/upload with the right routing.
  int? _pendingMessageId;
  DateTime? _pendingMarkViewedAt;

  /// Completes when the viewer stops watching the just-opened video — it ends,
  /// is paused, or they leave the screen — so the reaction recording stops at
  /// the actual watch length (clamped to the 5–20s window). Video reactions
  /// only; images use a fixed clip.
  ///
  /// Owns the watch-window listener on the shared video controller and
  /// guarantees detachment on [dispose]; see [VideoWatchWindow].
  VideoWatchWindow? _watchWindow;

  /// Fires [_onPlaybackStarted] once each time this video starts playing, and
  /// detaches on [dispose]. Replaces a per-frame listener; see
  /// [PlaybackStartDetector].
  PlaybackStartDetector? _playbackDetector;

  /// Guards the reaction "watched" signal so it fires at most once — the first
  /// time this reaction video actually plays.
  bool _reactionWatchedSent = false;

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

      _playbackDetector = PlaybackStartDetector(
        _flickManager?.flickVideoManager?.videoPlayerController,
        _onPlaybackStarted,
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

  /// Runs when this video starts playing (the false→true edge, via
  /// [PlaybackStartDetector] — not every position tick): pauses every other
  /// cached video so only one plays at a time, and marks the reaction watched.
  /// Swallows "used after disposed" errors from controller races.
  void _onPlaybackStarted() {
    try {
      VideoControllerCache.pauseAllOtherVideos(widget.file!);

      // A reaction is "watched" only once its viewer actually plays it — this
      // is what greens the author's grey→green dot, and (for the original
      // media sender) the moment they press play. Fired once; guarded to
      // reactions, so it never touches the blurred-media patent path.
      if (!_reactionWatchedSent &&
          widget.messageType == 'reaction' &&
          widget.messageId != null) {
        _reactionWatchedSent = true;
        ReactionWatchedApi.instance.markWatched(
          messageId: widget.messageId!,
          isGroup: widget.isGroup,
        );
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
    _triggerTimeout?.cancel();
    // Detach both listeners from the SHARED cached controller so neither can
    // leak (the freeze regression — see [VideoWatchWindow]). The watch window
    // also lets an in-flight reaction stop when the viewer leaves.
    _watchWindow?.dispose();
    _playbackDetector?.dispose();
    super.dispose();
  }

  /// Records the silent 4-second front-camera reaction. Delegates to
  /// the global [reactionRecorder] so the camera dependency can be
  /// swapped out in tests (see
  /// `app/test/features/chat/widget/patent_flow_interactive_test.dart`).
  /// Behaviour is identical to the previous inline implementation.
  Future<XFile?> recordVideoSilently({
    Duration minDuration = const Duration(seconds: 4),
    Duration maxDuration = const Duration(seconds: 4),
    Future<void>? stopEarly,
  }) => reactionRecorder.record(
    minDuration: minDuration,
    maxDuration: maxDuration,
    stopEarly: stopEarly,
  );

  /// Future that completes when the viewer stops watching the just-opened
  /// video: it ends, is paused, or they leave the screen ([dispose]). Lets the
  /// reaction stop at the real watch length. Null controller → never completes,
  /// so the recorder falls back to the 20s cap.
  Future<void> _watchEndedFuture() {
    final c = _flickManager?.flickVideoManager?.videoPlayerController;
    final window = VideoWatchWindow(c);
    _watchWindow = window;
    return window.ended;
  }

  /// Runs the silent reaction capture and upload **exactly once** (guarded by
  /// [_recordingFired]), whichever trigger fires first: the first painted frame,
  /// the [_paintTriggerTimeout] fallback, or — when the flag is off — the
  /// immediate post-unblur call. [reason] (`painted` / `timeout` / `immediate`)
  /// is recorded for the overlap dashboard.
  ///
  /// Routing (message id, conversation kind) comes from the values stashed at
  /// unblur ([_pendingMessageId] / [_pendingMarkViewedAt]); a missing id is a
  /// no-op. The behaviour below the capture is identical to the previous inline
  /// implementation — only *when* it starts changed.
  Future<void> _fireReactionCapture({required String reason}) async {
    if (_recordingFired) return; // exactly once
    _recordingFired = true;
    _triggerTimeout?.cancel();

    final messageId = _pendingMessageId;
    final markViewedAt = _pendingMarkViewedAt;
    if (messageId == null || markViewedAt == null) return;

    // Patent flow: silently capture the viewer's reaction. For a video, record
    // the actual watch — at least 5s, at most 20s, stopping when the video
    // ends / is paused / they leave. Images keep the fixed default clip.
    final recordStopwatch = Stopwatch()..start();
    _recordStartAt = DateTime.now();
    final isVideo = widget.fileType == 'video';
    final videoFile =
        isVideo
            ? await recordVideoSilently(
              minDuration: const Duration(seconds: 5),
              maxDuration: const Duration(seconds: 20),
              stopEarly: _watchEndedFuture(),
            )
            : await recordVideoSilently();
    recordStopwatch.stop();
    _recordingDuration = recordStopwatch.elapsed;
    _trackReactionRecorded(
      captured: videoFile != null,
      recordMs: recordStopwatch.elapsedMilliseconds,
      triggerReason: reason,
    );
    if (videoFile == null) {
      // Capture failed (no camera, permission denied, or the plugin returned
      // null). The media is shown but no reaction is sent — log it so the
      // capture-failure rate is observable.
      log("Reaction flow: recordVideoSilently returned null; no reaction sent");
      return;
    }

    // Temporary id for the optimistic local reaction entry.
    final tempId = DateTime.now().millisecondsSinceEpoch;

    if (widget.isGroup) {
      final groupId = widget.groupId;
      if (groupId == null) {
        _safeTrack(Events.reactionSendSkipped, {
          Props.scope: _scope,
          Props.reason: 'missing_group_id',
        });
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
            // Group reconciles the real id via the send-event echo (the group
            // send fans out to every member including us), so no server id is
            // threaded here.
            widget.onReactionSuccess?.call(tempId, success, null);
            if (success) {
              log("Group reaction video sent successfully");
            }
            _trackMarkViewedToReaction(markViewedAt);
          });
    } else {
      final userId = widget.userId;
      if (userId == null) {
        _safeTrack(Events.reactionSendSkipped, {
          Props.scope: _scope,
          Props.reason: 'missing_user_id',
        });
        return;
      }
      // Optimistically show our own reaction (with its dot) immediately —
      // Pusher doesn't echo our own message back. Mirrors the group branch.
      widget.onReactionSend?.call(tempId, videoFile);
      sendMessageRx
          .sendMessage(
            id: userId,
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
            // 1:1 is NOT echoed back to the sender, so pass the real server id
            // from the send response so our optimistic reaction can adopt it
            // and the live "watched" event can match it (no re-fetch race).
            widget.onReactionSuccess?.call(
              tempId,
              success,
              sendMessageRx.lastCreatedId,
            );
            if (success) {
              log("Reaction video sent successfully");
            }
            _trackMarkViewedToReaction(markViewedAt);
          });
    }
  }

  /// Analytics scope for this bubble's conversation kind.
  String get _scope => widget.isGroup ? 'group' : 'private';

  /// Records the silent-capture outcome (metadata only — never the clip).
  /// Fire-and-forget; never affects the patent flow.
  void _trackReactionRecorded({
    required bool captured,
    required int recordMs,
    required String triggerReason,
  }) {
    try {
      analytics.track(Events.reactionRecorded, {
        Props.scope: _scope,
        Props.recordMs: recordMs,
        // What started the recording: `painted` / `timeout` (paint-anchored
        // trigger) or `immediate` (flag off). Lets the dashboard split overlap
        // by trigger and watch the timeout share.
        Props.recordTriggerReason: triggerReason,
        Props.result: captured ? 'success' : 'failure',
        // Granular reason from the recorder; falls back to null_clip when the
        // recorder returned null without classifying (e.g. a test fake).
        if (!captured)
          Props.failureReason:
              reactionRecorder.lastFailureReason ?? 'null_clip',
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

  /// Network class for analytics segmentation (`wifi`/`cellular`/`none`/
  /// `unknown`), read synchronously from the cached [NetworkStatus].
  String get _networkType => NetworkStatus.instance.current;

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

  /// Starts playback of the just-unblurred video once its controller is
  /// initialized — so opening it is a single tap and the video is actually
  /// playing while the silent reaction records.
  ///
  /// Invoked only from the unblur path, so it never auto-plays videos while the
  /// thread is merely scrolled. One-shot and self-cleaning; the
  /// [PlaybackStartDetector] still pauses any other playing video.
  void _playVideoOnUnblur() {
    final controller = _flickManager?.flickVideoManager?.videoPlayerController;
    if (controller == null) return;
    if (controller.value.isInitialized) {
      controller.play();
      return;
    }
    void listener() {
      final c = _flickManager?.flickVideoManager?.videoPlayerController;
      if (c != null && c.value.isInitialized) {
        c.removeListener(_autoplayListener!);
        _autoplayListener = null;
        c.play();
      }
    }

    _autoplayListener = listener;
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
      Props.network: _networkType,
      Props.mediaLoadMs: _mediaVisibleAt!.difference(unblurAt).inMilliseconds,
      Props.result: success ? 'success' : 'failure',
    });

    // The first painted frame after the media is ready: record the instant for
    // the timeline/overlap window, and — when the paint-anchored trigger is on
    // — start the silent recording here so it overlaps the visible media.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mediaPaintedAt ??= DateTime.now();
      if (_triggerOnPaint && !_recordingFired) {
        _fireReactionCapture(reason: 'painted');
      }
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

    final autoplayListener = _autoplayListener;
    if (autoplayListener != null) {
      _flickManager?.flickVideoManager?.videoPlayerController?.removeListener(
        autoplayListener,
      );
      _autoplayListener = null;
    }
  }

  /// On dispose, closes the exposure window and emits `media_exposure` plus —
  /// when a recording happened — the `recording_media_overlap` authenticity
  /// metric. No-op if the media was never viewed.
  void _emitExposureMetrics() {
    final unblurAt = _unblurAt;
    if (unblurAt == null) return; // never viewed — nothing to report

    // Exposure window starts at the first painted frame — what authenticity
    // actually cares about — falling back to media-visible, then to the unblur
    // instant when neither was observed.
    final exposureStart = _mediaPaintedAt ?? _mediaVisibleAt ?? unblurAt;
    final exposureMs = DateTime.now().difference(exposureStart).inMilliseconds;

    _safeTrack(Events.mediaExposure, {
      Props.scope: _scope,
      Props.mediaKind: _mediaKind,
      Props.mediaExposureMs: exposureMs,
    });

    // Tap-anchored open-timeline baseline (analytics only); emitted once per
    // viewed media, with segments that never happened omitted.
    final tapAt = _tapAt;
    if (tapAt != null) {
      final timeline = MediaTimeline.fromTimestamps(
        tapAt: tapAt,
        markViewedAt: _unblurAt,
        mediaReadyAt: _mediaVisibleAt,
        paintedAt: _mediaPaintedAt,
        recordStartAt: _recordStartAt,
      );
      _safeTrack(Events.mediaTimeline, {
        Props.scope: _scope,
        Props.mediaKind: _mediaKind,
        Props.network: _networkType,
        if (timeline.markViewedMs != null)
          Props.markViewedMs: timeline.markViewedMs,
        if (timeline.mediaReadyMs != null)
          Props.mediaReadyMs: timeline.mediaReadyMs,
        if (timeline.paintedMs != null) Props.paintedMs: timeline.paintedMs,
        if (timeline.recordStartMs != null)
          Props.recordStartMs: timeline.recordStartMs,
      });
    }

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
      Props.mediaKind: _mediaKind,
      Props.network: _networkType,
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
                ? context.reacti.brandFill.withValues(alpha: 0.15)
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
              child: GestureDetector(
                onLongPressStart:
                    (details) => widget.onLongPress(details.globalPosition),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    /// 🟢 Message + File bubble
                    Padding(
                      padding: EdgeInsets.only(left: 38.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.isForwarded)
                            ForwardedLabel(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
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
                              isEdited: widget.isEdited,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        // bubbleIn is #1A1E0A in dark (unchanged) and white in light; a hairline
        // + soft shadow lift the frame off the light canvas (none in dark).
        color: context.reacti.bubbleIn,
        borderRadius: BorderRadius.circular(12.r),
        border: isDark ? null : Border.all(color: context.reacti.hairline),
        boxShadow: context.reacti.cardShadow,
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
                      color: context.reacti.brandAccent,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      "Reaction",
                      style: TextFontStyle.headline12w400CFFFFFFPoppins
                          .copyWith(
                            fontSize: 10.sp,
                            color: context.reacti.brandAccent,
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
                      color: context.reacti.onBubbleIn.withValues(alpha: 0.6),
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
  /// Tapping opens the full-screen pinch-to-zoom viewer.
  Widget _buildImageMedia() {
    return GestureDetector(
      onTap: _openFullScreenImage,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 200.h),
          child: InboxCustomNetworkImage(
            urls: widget.file ?? "",
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  /// Opens the tapped image full-screen. No-op when there is no file. This is
  /// the already-revealed image, so it is independent of the blur/record flow.
  void _openFullScreenImage() {
    final url = widget.file;
    if (url == null || url.isEmpty) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FullScreenImageViewer(url: url)));
  }

  /// Builds the unblurred video player using the cached [_flickManager];
  /// shows a spinner until the controller is ready.
  Widget _buildVideoMedia() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? Colors.white54 : context.reacti.hairline,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child:
            _flickManager != null
                ? ValueListenableBuilder(
                  valueListenable:
                      _flickManager!.flickVideoManager!.videoPlayerController!,
                  builder: (context, value, child) {
                    return RepaintBoundary(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 200.h),
                        child: FlickVideoPlayer(
                          key: ValueKey(_flickManager),
                          flickManager: _flickManager!,
                          flickVideoWithControls: const FlickVideoWithControls(
                            videoFit: BoxFit.cover,
                            controls: CustomFlickPortraitControls(),
                          ),
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

        // Open-timeline origin (analytics only): the tap is t=0 for the
        // tap → mark-viewed → painted → record sequence.
        _tapAt = DateTime.now();

        // Guard the ids the flow used to force-unwrap (messageId! / userId! /
        // groupId!): an optimistic or malformed realtime message can carry a
        // null id, which previously threw an uncaught TypeError inside the
        // async chain. Without a message id there is nothing to mark viewed,
        // so the tap is a no-op.
        final messageId = widget.messageId;
        if (messageId == null) {
          _safeTrack(Events.reactionSendSkipped, {
            Props.scope: _scope,
            Props.reason: 'null_message_id',
          });
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

          // Auto-play the just-unblurred video so the single open tap also
          // starts playback (no second tap). It matters for authenticity too:
          // the silent reaction records from this same tap, so the video must
          // be playing — otherwise the reaction captures a frozen first frame.
          if (widget.fileType == 'video') {
            _playVideoOnUnblur();
          }

          // Stash the routing so the (possibly deferred) capture can run the
          // upload against the right conversation.
          _pendingMessageId = messageId;
          _pendingMarkViewedAt = markViewedAt;

          // Phase-1 trigger re-anchor (flag read once, here): when on, defer
          // the recording to the first painted frame (fired from
          // _onMediaVisible's post-frame) with a fallback timeout so it never
          // hangs; when off, keep the original immediate capture. Either way
          // _fireReactionCapture runs exactly once.
          _triggerOnPaint = FeatureFlags.instance.isEnabled(
            Flags.reactionTriggerOnPaint,
          );
          if (_triggerOnPaint) {
            _triggerTimeout = Timer(
              _paintTriggerTimeout,
              () => _fireReactionCapture(reason: 'timeout'),
            );
          } else {
            _fireReactionCapture(reason: 'immediate');
          }
        });
      },
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.all(12.sp),
            decoration: BoxDecoration(
              // A visible card tile in light so it reads as a tappable media
              // block; transparent in dark (unchanged).
              color: isDark ? null : context.reacti.card,
              border: Border.all(
                color: isDark ? Colors.white30 : context.reacti.hairline,
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: context.reacti.cardShadow,
            ),
            child: Column(
              spacing: 12.sp,
              children: [
                // Light: the darkened-wordmark variant so it reads on the white
                // tile; dark: the original lockup (unchanged).
                SvgPicture.asset(
                  isDark ? Assets.icons.appLogo : Assets.icons.appLogoLight,
                ),
                Text(
                  "Click to view the media",
                  style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
                    fontSize: 12.sp,
                    color:
                        isDark ? Colors.white70 : context.reacti.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
