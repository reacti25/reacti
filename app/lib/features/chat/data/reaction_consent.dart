import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gates the silent reaction recording behind one-time consent + OS camera and
/// microphone permission (DG1).
///
/// The patented flow records a short front-camera reaction when a recipient
/// opens a media message. It may only run if the user has **consented** (a
/// one-time choice persisted in [appData]) **and** the OS camera + microphone
/// permissions are granted. When either is missing — including when the user
/// later revokes the OS permission — [ensure] shows a pop-up that lets them
/// consent and grant access inline, or cancel (and the media stays locked).
///
/// Exposed as a swappable global ([reactionConsentGate]) — mirroring
/// [reactionRecorder] — so widget tests can inject a fake that allows or blocks
/// without touching `permission_handler` or showing a dialog. Final legal
/// wording for the dialog is pending lawyer review.
class ReactionConsentGate {
  /// Whether the user has consented to the reaction recording.
  bool get hasConsent => appData.read(kKeyReactionConsent) == true;

  /// Persists that the user has consented.
  Future<void> grantConsent() => appData.write(kKeyReactionConsent, true);

  /// Returns `true` if the reaction may be recorded — i.e. consent has been
  /// given **and** camera + microphone permission are granted.
  ///
  /// When something is missing, shows the consent pop-up: on **Allow** it
  /// records consent and requests the OS permissions; on **Cancel** (or if the
  /// permission is then denied) it returns `false` and the caller must not
  /// record.
  Future<bool> ensure(BuildContext context) async {
    if (hasConsent && await _permissionsGranted()) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }
    final accepted = await _showConsentDialog(context);
    if (accepted != true) {
      return false;
    }

    await grantConsent();
    return _requestPermissions();
  }

  Future<bool> _permissionsGranted() async =>
      await Permission.camera.isGranted &&
      await Permission.microphone.isGranted;

  Future<bool> _requestPermissions() async {
    final camera = await Permission.camera.request();
    final microphone = await Permission.microphone.request();

    return camera.isGranted && microphone.isGranted;
  }

  Future<bool?> _showConsentDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Reaction recording'),
            // Placeholder copy — final legal wording is pending lawyer review.
            content: const Text(
              'Opening a media message records a short front-camera reaction '
              '(video and audio) that is shared back with the sender. To use '
              'media messages you must allow this and grant camera & microphone '
              'access. You can decline, but media messages will stay locked.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Allow'),
              ),
            ],
          ),
    );
  }
}

/// Process-wide consent gate used by the chat widgets.
///
/// Swappable so tests can inject a fake (see [ReactionConsentGate]).
ReactionConsentGate reactionConsentGate = ReactionConsentGate();
