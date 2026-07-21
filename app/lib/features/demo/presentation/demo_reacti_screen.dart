import 'dart:async';

import 'package:camera/camera.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reacti_app/analytics/analytics_locator.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/theme/app_theme.dart';

/// The three steps of the one-time practice ("demo") Reacti.
enum _DemoStep { primer, capturing, reveal }

/// A harmless, fully-local practice Reacti shown once to every first-time user.
///
/// Teaches the core loop against the empty home: the user opens a canned
/// "friend" moment, their front camera records their genuine reaction *exactly
/// like the real product*, and the reveal shows what a friend would receive —
/// but **nothing is ever sent**. The capture reuses the same upload-free
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

  /// The canned "friend" media shown as the thing being opened. Placeholder
  /// today — swap the file at this path for the real clip (see the asset
  /// folder's README). Kept as a field so a test / future variant can point
  /// elsewhere without touching the flow.
  static const String friendMediaAsset = 'assets/demo/friend_moment.jpg';

  /// The canned friend's display name (per wireframe).
  static const String friendName = 'Maya';

  @override
  State<DemoReactiScreen> createState() => _DemoReactiScreenState();
}

class _DemoReactiScreenState extends State<DemoReactiScreen> {
  _DemoStep _step = _DemoStep.primer;

  /// The locally-captured reaction clip (never uploaded). Null when the user
  /// denied camera/mic or capture failed — the reveal degrades gracefully.
  XFile? _reaction;

  /// Seconds elapsed in the current recording, for the "● REC 00:0X" chrome.
  int _recSeconds = 0;
  Timer? _recTimer;

  @override
  void dispose() {
    _recTimer?.cancel();
    super.dispose();
  }

  /// Step 1 → 2: soft-ask camera/mic, then run the local capture.
  Future<void> _startDemo() async {
    analytics.track(Events.demoStarted, const {});

    final granted = await _ensureCamMicPrimer();

    if (!mounted) return;
    setState(() {
      _step = _DemoStep.capturing;
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
    }

    if (!mounted) return;
    setState(() => _step = _DemoStep.reveal);
  }

  /// Step 3 CTA: mark the demo seen, log completion, and return to the app.
  void _finish() {
    appData.write(kKeyDemoSeen, true);
    analytics.track(Events.demoReactionCompleted, const {});
    Navigator.of(context).pop();
  }

  /// The Feature 8c soft-ask primer, shared with the first real Reacti open.
  ///
  /// Shows a friendly one-time explanation ("Ready for your demo?") before the
  /// OS dialog, then requests camera + microphone together. Returns whether
  /// the camera is usable. Persists [kKeyCamMicPrimerShown] so it is a
  /// one-time soft-ask.
  ///
  /// ponytail: inlined here for the demo. Feature 8c extracts this into a
  /// shared primer used at the first real capture too — lift it out then.
  Future<bool> _ensureCamMicPrimer() async {
    if (appData.read(kKeyCamMicPrimerShown) != true) {
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Ready for your demo?'),
              content: const Text(
                'Reacti needs camera and microphone only when you open a Reacti.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Continue'),
                ),
              ],
            ),
      );
      appData.write(kKeyCamMicPrimerShown, true);
    }

    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses[Permission.camera]?.isGranted ?? false;
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
            _DemoStep.primer => _buildPrimer(context),
            _DemoStep.capturing => _buildCapturing(context),
            _DemoStep.reveal => _buildReveal(context),
          },
        ),
      ),
    );
  }

  /// Step 1 — primer + single CTA.
  Widget _buildPrimer(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'DEMO REACTI · JUST FOR YOU',
          textAlign: TextAlign.center,
          style: TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
            color: context.reacti.brandAccent,
            letterSpacing: 1.2,
          ),
        ),
        UIHelper.verticalSpace(12.h),
        Text(
          'Tap when you\'re ready.',
          textAlign: TextAlign.center,
          style: TextFontStyle.headline20w600CFFFFFFPoppins.copyWith(
            color: context.reacti.textPrimary,
          ),
        ),
        UIHelper.verticalSpace(12.h),
        Text(
          'First time here? This practice reaction starts immediately and '
          'stays private on this phone.',
          textAlign: TextAlign.center,
          style: TextFontStyle.headline16w400CCCCCCCPoppins.copyWith(
            color: context.reacti.textSecondary,
          ),
        ),
        UIHelper.verticalSpace(32.h),
        FilledButton(
          onPressed: _startDemo,
          child: const Text('Open demo Reacti'),
        ),
      ],
    );
  }

  /// Step 2 — the friend media with real recording chrome over it.
  Widget _buildCapturing(BuildContext context) {
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
                child: Image.asset(
                  DemoReactiScreen.friendMediaAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _mediaFallback(context),
                ),
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

  /// Step 3 — the composite "what a friend receives", then the send CTA.
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Image.asset(
              DemoReactiScreen.friendMediaAsset,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) => _mediaFallback(context),
            ),
          ),
        ),
        UIHelper.verticalSpace(12.h),
        _reactionTile(context),
        UIHelper.verticalSpace(8.h),
        Text(
          'This is what your friend receives.',
          textAlign: TextAlign.center,
          style: TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
            color: context.reacti.textSecondary,
          ),
        ),
        UIHelper.verticalSpace(16.h),
        FilledButton(
          onPressed: _finish,
          child: const Text('Send your first Reacti'),
        ),
      ],
    );
  }

  /// Neutral fill shown if the demo media asset can't be decoded (e.g. missing
  /// placeholder), so the flow never crashes on a bad asset.
  Widget _mediaFallback(BuildContext context) =>
      ColoredBox(color: context.reacti.surfaceVariant);

  /// The "● Your reaction" row beneath the original. Shows a captured-state
  /// tile (playback is a future upgrade) or a soft note when capture was
  /// skipped/denied — the recording is never sent either way.
  Widget _reactionTile(BuildContext context) {
    final captured = _reaction != null;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: context.reacti.card,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(
            captured ? Icons.circle : Icons.videocam_off,
            color: captured ? Colors.red : context.reacti.textTertiary,
            size: 14.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
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
