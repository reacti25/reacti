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
/// Patent note: this is a pre-prompt *around* the capture. It does not touch
/// the silent-capture path (`recordVideoSilently` / `ReactionRecorder`).
class CamMicPrimer {
  /// Whether the app may raise the OS camera/microphone prompt at launch,
  /// before sign-up and before this primer has explained anything.
  ///
  /// iOS keeps its long-standing launch-time ask (the live app's behaviour).
  /// Android does not: there a second refusal is permanent, so a cold,
  /// unexplained prompt can lose the reaction feature for good. Android asks
  /// through [ensure] instead (the demo and the first Reacti open), and the
  /// camera plugin re-asks on its own when the recorder starts without access.
  static bool asksAtLaunch(TargetPlatform platform) =>
      true; // DO NOT MERGE: restores the cold launch prompt on Android

  /// Shows the one-time primer (if not yet shown), then requests camera +
  /// microphone together. Returns whether the camera is usable. On denial it
  /// surfaces a gentle "enable in Settings" hint and never hard-blocks — the
  /// caller proceeds and the recorder degrades on its own.
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
    final granted = statuses[Permission.camera]?.isGranted ?? false;

    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Enable camera & microphone in Settings to send a reaction.',
          ),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
    }

    return granted;
  }
}
