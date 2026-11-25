import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reacti_app/analytics/permission_analytics.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';

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
  /// Fails open: if the status cannot be read at all (no permission plugin,
  /// as on the test host) the media opens, so a broken plugin can never lock
  /// everyone out of their media. A real refusal is never an error.
  static Future<bool> allowsOpening(BuildContext context) async {
    try {
      if (appData.read(kKeyCamMicPrimerShown) == true &&
          await Permission.camera.isGranted &&
          await Permission.microphone.isGranted) {
        return true;
      }
    } catch (_) {
      return true;
    }
    if (!context.mounted) return false;
    return ensure(context);
  }

  /// Shows the one-time primer (if not yet shown), then requests camera +
  /// microphone together. Returns whether both are allowed, which is what a
  /// reaction needs. On denial it shows [deniedMessage] with a way to
  /// Settings; what a "no" means is the caller's call (the chat keeps the
  /// media sealed, the demo goes on without a recording).
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(deniedMessage),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
    }

    return granted;
  }
}
