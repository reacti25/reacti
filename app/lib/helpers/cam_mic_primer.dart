import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reacti_app/analytics/permission_analytics.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/theme/app_theme.dart';

/// Just-in-time camera/mic permission primer (Feature 8c).
///
/// A friendly one-time soft-ask shown *right before* the first camera/mic use
/// — the first Reacti open or the demo — so the OS prompt never appears cold.
/// Persists [kKeyCamMicPrimerShown] so the explanation shows once; after that
/// [ensure] goes straight to the (idempotent) OS permission request.
///
/// It is also the gate on opening sealed media ([allowsOpening]): no camera
/// and microphone, no reaction, so no viewing.
///
/// Patent note: this is a pre-prompt *around* the capture. It does not touch
/// the silent-capture path (`recordVideoSilently` / `ReactionRecorder`).
class CamMicPrimer {
  /// Title of the box shown without camera and microphone access.
  static const deniedTitle = 'Camera and microphone are off';

  /// Shown when sealed media is tapped, or the demo started, without camera
  /// and microphone access. No em dashes.
  static const deniedMessage =
      'Reacti needs your camera and microphone to open media. '
      'Allow them in Settings.';

  /// Whether the app may raise the OS camera/microphone prompt at launch,
  /// before sign-up and before this primer has explained anything.
  ///
  /// iOS keeps its long-standing launch-time ask (the live app's behaviour).
  /// Android does not: there a second refusal is permanent, so a cold,
  /// unexplained prompt can lose the reaction feature for good. Android asks
  /// through [ensure] instead (the demo and the first Reacti open), and the
  /// camera plugin re-asks on its own when the recorder starts without access.
  static bool asksAtLaunch(TargetPlatform platform) =>
      platform == TargetPlatform.iOS;

  /// Whether sealed media may be opened now: only when its reaction can be
  /// recorded. The reaction is what opening costs, and the recorder films
  /// with sound, so it needs the camera and the microphone.
  ///
  /// With both already allowed this is two status reads and nothing is shown.
  /// Otherwise it goes through [ensure]: the first time that explains and
  /// asks, and a refusal shows [deniedMessage] with a way to Settings.
  ///
  /// Fails open: if the status cannot be read (a broken plugin) the media
  /// opens, so a fault can never lock everyone out of their media. A real
  /// refusal is never an error.
  static Future<bool> allowsOpening(BuildContext context) async {
    if (appData.read(kKeyCamMicPrimerShown) == true) {
      // Only the phones have a permission system; anywhere else (the test
      // host) the read would never be answered.
      if (!onPhone) return true;
      try {
        if (await Permission.camera.isGranted &&
            await Permission.microphone.isGranted) {
          return true;
        }
      } catch (_) {
        return true;
      }
    }
    if (!context.mounted) return false;
    return ensure(context);
  }

  /// Whether this is a phone, where permissions exist. Tests set it to true
  /// to reach their mocked permission channel through [allowsOpening].
  @visibleForTesting
  static bool onPhone = Platform.isIOS || Platform.isAndroid;

  /// Shows the one-time primer (if not yet shown), then requests camera +
  /// microphone together. Returns whether both are allowed, which is what a
  /// reaction needs. On denial it shows the [_showDenied] box; what a "no"
  /// means is the caller's call (the chat keeps the media sealed, the demo
  /// goes on without a recording).
  static Future<bool> ensure(
    BuildContext context, {
    String title = 'Camera & microphone',
  }) async {
    if (appData.read(kKeyCamMicPrimerShown) != true) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(title),
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
      }
      appData.write(kKeyCamMicPrimerShown, true);
    }

    final statuses = await [Permission.camera, Permission.microphone].request();
    // The camera answer is the one that decides whether this person can use
    // the app at all, so it is reported either way rather than only on denial.
    trackPermissionStatus(Permissions.camera, statuses[Permission.camera]);
    trackPermissionStatus(
      Permissions.microphone,
      statuses[Permission.microphone],
    );
    final granted = statuses.values.every((status) => status.isGranted);

    if (!granted && context.mounted) {
      // Not awaited: the caller already has its answer, and the box stays
      // until the person picks one of its two buttons.
      unawaited(_showDenied(context));
    }

    return granted;
  }

  /// The box shown when camera or microphone access is refused: bold, in the
  /// middle of the screen, with two ways out. "Open Settings" goes where
  /// access is given; "Not now" just closes it for someone who chose not to
  /// give access (the media then stays sealed).
  static Future<void> _showDenied(BuildContext context) {
    final reacti = context.reacti;
    return showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            key: const Key('cam-mic-denied'),
            icon: const Icon(Icons.videocam_off_outlined, size: 36),
            title: const Text(
              deniedTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: const Text(deniedMessage, textAlign: TextAlign.center),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                key: const Key('cam-mic-not-now'),
                style: TextButton.styleFrom(
                  foregroundColor: reacti.textSecondary,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Not now'),
              ),
              FilledButton(
                key: const Key('cam-mic-settings'),
                style: FilledButton.styleFrom(
                  backgroundColor: reacti.brandFill,
                  foregroundColor: reacti.onBrandFill,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }
}
