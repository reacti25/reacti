import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:reacti_app/analytics/analytics_locator.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/helpers/cam_mic_primer.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// The stages of the one-time practice ("demo") Reacti — mirroring the real
/// receiver loop: a sealed clip you open, the silent capture, then the reveal.
enum _DemoStep { sealed, recording, reveal }

/// A harmless, fully-local practice Reacti shown once to every first-time user.
///
/// Teaches the *real* core loop against the empty home: a "friend" clip arrives
/// **sealed** (blurred); tapping to open unblurs it and silently records the
/// user's genuine reaction *exactly like the real product*; the reveal then
/// **plays that reaction back** to show what a friend would receive — but
/// **nothing is ever sent**. The capture reuses the same upload-free
/// [reactionRecorder] as the patent flow; this screen never calls
/// `sendMessage` / `mark-viewed` / any reaction upload, so it cannot touch the
/// patented send path (a test pins zero sends).
///
/// ponytail: a single stateful widget with a step enum, not a
/// controller/strategy split. The plan's `DemoController` seam is only needed
/// for the future AI-coach variant (out of scope); add it when that lands.
class DemoReactiScreen extends StatefulWidget {
  /// Creates the demo Reacti screen.
  const DemoReactiScreen({super.key});

  /// The canned "friend" media clip shown as the thing being opened. To change
  /// it, just drop a new video at this exact path — no code change (see the
  /// asset folder's README). Must be an iOS-playable H.264 MP4.
  static const String friendMediaAsset = 'assets/demo/friend_moment.mp4';

  /// The canned friend's display name (per wireframe).
  static const String friendName = 'Maya';

  @override
  State<DemoReactiScreen> createState() => _DemoReactiScreenState();
}

class _DemoReactiScreenState extends State<DemoReactiScreen> {
  _DemoStep _step = _DemoStep.sealed;

  /// The locally-captured reaction clip (never uploaded). Null when the user
  /// denied camera/mic or capture failed — the reveal degrades gracefully.
  XFile? _reaction;

  /// Seconds elapsed in the current recording, for the "● REC 00:0X" chrome.
  int _recSeconds = 0;
  Timer? _recTimer;

  /// Plays the looping "friend" clip (sealed → blurred, opened → clear).
  late final VideoPlayerController _friendController;
  late final Future<void> _friendInit;

  /// Plays back the captured reaction on the reveal. Created after capture;
  /// null when nothing was captured.
  VideoPlayerController? _reactionController;
  Future<void>? _reactionInit;

  /// One-shot guard: the sealed media and its button both open the demo, so a
  /// double-tap must not start two captures.
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    // Marked seen on OPEN, not on finish. The demo can be left by the app-bar
    // back button or an iOS swipe-back, neither of which reaches _finish() — so
    // anyone who did not tap all the way through got the demo again on every
    // launch, forever. Same call the walkthrough makes for the same reason: a
    // user who backs out has seen it, and being shown it again is the worse
    // failure. Profile's "Try a demo Reacti" is the way back in.
    appData.write(kKeyDemoSeen, true);
    _friendController = VideoPlayerController.asset(
      DemoReactiScreen.friendMediaAsset,
    );
    // Loop the muted friend clip. On failure the future rejects and
    // _friendMedia falls back to a neutral fill — the flow never blocks on the
    // video. Wrapped in an async method so even a *synchronous* plugin throw
    // (the video platform is unimplemented under `flutter test`) surfaces as a
    // Future error the FutureBuilder handles, not an uncaught exception.
    _friendInit = _initClip(_friendController);
  }

  /// Initialises [c] and starts it looping, muted. Any failure is swallowed so
  /// the returned future always completes cleanly — callers gate on
  /// `isInitialized` and show a fallback when the clip isn't playable.
  Future<void> _initClip(VideoPlayerController c) async {
    try {
      await c.initialize();
      if (!mounted) return;
      c
        ..setLooping(true)
        ..setVolume(0)
        ..play();
    } catch (_) {
      // No video (platform unimplemented under `flutter test`, or a bad asset).
    }
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    // Guarded: disposing a controller whose init failed (e.g. tests) can throw.
    try {
      _friendController.dispose();
    } catch (_) {}
    try {
      _reactionController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  /// Open the sealed clip: soft-ask camera/mic, unblur + record, then reveal.
  /// Mirrors the real receiver flow (open → silent capture) minus any upload.
  Future<void> _openAndRecord() async {
    if (_opening) return;
    _opening = true;
    analytics.track(Events.demoStarted, const {});

    final granted = await CamMicPrimer.ensure(
      context,
      title: 'Ready for your demo?',
    );

    if (!mounted) return;
    setState(() {
      _step = _DemoStep.recording;
      _recSeconds = 0;
    });

    // If the user denied, skip capture but still show the explanation reveal —
    // never hard-block. Otherwise run the real 4s silent capture window.
    if (granted) {
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSeconds++);
      });
      // Reuse the patent flow's recorder (default 4s). It captures locally and
      // returns a file; it does NOT upload. We never send it anywhere.
      _reaction = await reactionRecorder.record();
      _recTimer?.cancel();

      // Prepare playback of the just-captured reaction for the reveal.
      final r = _reaction;
      if (r != null) {
        final c = VideoPlayerController.file(File(r.path));
        _reactionController = c;
        _reactionInit = _initClip(c);
      }
    }

    if (!mounted) return;
    setState(() => _step = _DemoStep.reveal);
  }

  /// Reveal CTA: log completion and return to the app.
  ///
  /// The seen flag is set in [initState] — reaching here is not what makes the
  /// demo count as shown. This event is specifically *completion*, so it stays
  /// distinct from merely opening it.
  void _finish() {
    analytics.track(Events.demoReactionCompleted, const {});
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.reacti.canvas,
      appBar: AppBar(
        title: const Text('Welcome to Reacti'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: switch (_step) {
            _DemoStep.sealed => _buildSealed(context),
            _DemoStep.recording => _buildRecording(context),
            _DemoStep.reveal => _buildReveal(context),
          },
        ),
      ),
    );
  }

  /// Step 1 — the sealed (blurred) friend clip with the "open" primer overlaid,
  /// exactly how a real Reacti arrives. Tapping anywhere (or the button) opens.
  Widget _buildSealed(BuildContext context) {
    return GestureDetector(
      onTap: _openAndRecord,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The clip is playing underneath, but blurred + dimmed = "sealed".
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: _friendMedia(context),
            ),
            const ColoredBox(color: Colors.black45),
            Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'DEMO REACTI · JUST FOR YOU',
                    textAlign: TextAlign.center,
                    style: TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
                      color: context.reacti.brandAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                  UIHelper.verticalSpace(16.h),
                  Icon(Icons.lock_outline, color: Colors.white, size: 40.sp),
                  UIHelper.verticalSpace(16.h),
                  Text(
                    'Tap when you\'re ready.',
                    textAlign: TextAlign.center,
                    style: TextFontStyle.headline20w600CFFFFFFPoppins.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  UIHelper.verticalSpace(12.h),
                  Text(
                    'This practice reaction starts immediately and stays '
                    'private on this phone.',
                    textAlign: TextAlign.center,
                    style: TextFontStyle.headline16w400CCCCCCCPoppins.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  UIHelper.verticalSpace(28.h),
                  FilledButton(
                    onPressed: _openAndRecord,
                    child: const Text('Open demo Reacti'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 2 — the now-open friend clip with real recording chrome over it.
  /// No self-preview, mirroring the real silent capture ("No preview").
  Widget _buildRecording(BuildContext context) {
    final secs = _recSeconds.clamp(0, 99).toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: _friendMedia(context),
              ),
              Positioned(
                top: 12.h,
                left: 12.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 12.sp),
                      SizedBox(width: 6.w),
                      Text(
                        'REC 00:$secs',
                        style: TextFontStyle.headline14w500CFFFFFFPoppins
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        UIHelper.verticalSpace(16.h),
        Text(
          'No countdown. No preview. No retakes.',
          textAlign: TextAlign.center,
          style: TextFontStyle.headline16w400CCCCCCCPoppins.copyWith(
            color: context.reacti.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Step 3 — the composite a friend receives: the original clip on top, the
  /// user's own reaction playing beneath, then the send CTA.
  Widget _buildReveal(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Demo Reacti',
          style: TextFontStyle.headline18w400CFFFFFFPoppins.copyWith(
            color: context.reacti.textPrimary,
          ),
        ),
        UIHelper.verticalSpace(8.h),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: _friendMedia(context),
          ),
        ),
        UIHelper.verticalSpace(12.h),
        Row(
          children: [
            Icon(Icons.circle, color: Colors.red, size: 12.sp),
            SizedBox(width: 6.w),
            Text(
              'Your reaction',
              style: TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
                color: context.reacti.textPrimary,
              ),
            ),
          ],
        ),
        UIHelper.verticalSpace(8.h),
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: _reactionView(context),
          ),
        ),
        UIHelper.verticalSpace(8.h),
        Text(
          'This is what your friend receives. The recording is never sent.',
          textAlign: TextAlign.center,
          style: TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
            color: context.reacti.textSecondary,
          ),
        ),
        UIHelper.verticalSpace(12.h),
        FilledButton(
          onPressed: _finish,
          child: const Text('Send your first Reacti'),
        ),
      ],
    );
  }

  /// The looping friend clip, cover-fitted to fill its box; a neutral fill
  /// until it initialises (or if it can't — missing plugin in tests, bad
  /// asset), so the flow never blocks on the video.
  Widget _friendMedia(BuildContext context) => _coverVideo(
    controller: _friendController,
    init: _friendInit,
    fallback: _mediaFallback(context),
  );

  /// The captured reaction, played back cover-fitted; falls back to a text tile
  /// when nothing was captured (denied) or the clip can't play (tests).
  Widget _reactionView(BuildContext context) {
    final c = _reactionController;
    final init = _reactionInit;
    if (c == null || init == null) return _reactionTile(context);
    return _coverVideo(
      controller: c,
      init: init,
      fallback: _reactionTile(context),
    );
  }

  /// Shared cover-fitted video builder: shows [controller] once initialised,
  /// else [fallback]. Never throws on an uninitialised/failed controller.
  Widget _coverVideo({
    required VideoPlayerController controller,
    required Future<void> init,
    required Widget fallback,
  }) {
    return FutureBuilder<void>(
      future: init,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done &&
            !snap.hasError &&
            controller.value.isInitialized) {
          final size = controller.value.size;
          return SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(controller),
              ),
            ),
          );
        }
        return fallback;
      },
    );
  }

  /// Neutral fill shown while a clip loads or if it can't be decoded, so the
  /// flow never crashes on a bad asset.
  Widget _mediaFallback(BuildContext context) =>
      ColoredBox(color: context.reacti.surfaceVariant);

  /// Fallback for the reaction area when there's no playable reaction: a soft
  /// note (captured-but-unplayable, or camera-off). The clip is never sent.
  Widget _reactionTile(BuildContext context) {
    final captured = _reaction != null;
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.all(12.w),
      color: context.reacti.card,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            captured ? Icons.check_circle : Icons.videocam_off,
            color:
                captured
                    ? context.reacti.brandAccent
                    : context.reacti.textTertiary,
            size: 14.sp,
          ),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              captured
                  ? 'Your reaction — kept only on this phone'
                  : 'Camera off — no reaction captured',
              style: TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
                color: context.reacti.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
