import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gates the silent reaction recording behind the OS **camera + microphone**
/// permission (DG1).
///
/// The patented flow records a short front-camera reaction when a recipient
/// opens a media message. Granting the camera and microphone permission *is*
/// the user's consent: while it is granted, the flow runs **silently** — the
/// user never sees a prompt. The permission is requested once at registration
/// ([requestPermissions]).
///
/// Only when the permission is **missing** — declined at registration, or
/// later turned off in the phone's Settings — does [ensure] show a pop-up at
/// the moment the user taps to open media, letting them grant access (re-ask,
/// or open Settings if permanently denied) or cancel (the media stays locked).
///
/// Exposed as a swappable global ([reactionConsentGate]) — mirroring
/// [reactionRecorder] — so widget tests can inject a fake that allows or blocks
/// without touching `permission_handler` or showing a dialog. Final dialog
/// wording is pending lawyer review.
class ReactionConsentGate {
  /// Whether camera + microphone are both currently granted.
  Future<bool> _granted() async =>
      await Permission.camera.isGranted &&
      await Permission.microphone.isGranted;

  /// Requests the camera + microphone permission (the OS prompts). Called once
  /// at registration — if the user grants, they never see the in-app pop-up.
  Future<void> requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
  }

  /// Returns `true` if the reaction may be recorded — i.e. camera + microphone
  /// are granted.
  ///
  /// When granted, returns immediately and **silently** (no dialog). When
  /// missing, shows a pop-up: on **Allow** it re-requests the permission (or
  /// opens Settings if it was permanently denied); on **Cancel** (or if still
  /// denied) it returns `false` and the caller must not record.
  Future<bool> ensure(BuildContext context) async {
    if (await _granted()) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }
    final allow = await _showPermissionDialog(context);
    if (allow != true) {
      return false;
    }

    return _requestOrOpenSettings();
  }

  Future<bool> _requestOrOpenSettings() async {
    final camera = await Permission.camera.status;
    final microphone = await Permission.microphone.status;

    // A permanently-denied permission can't be re-prompted; the user must
    // change it in Settings.
    if (camera.isPermanentlyDenied || microphone.isPermanentlyDenied) {
      await openAppSettings();
      return _granted();
    }

    await Permission.camera.request();
    await Permission.microphone.request();
    return _granted();
  }

  Future<bool?> _showPermissionDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Camera & microphone needed'),
            // Placeholder copy — final legal wording is pending lawyer review.
            content: const Text(
              'Opening a media message records a short front-camera reaction '
              '(video and audio) that is shared back with the sender. To open '
              'media you need to allow camera & microphone access. You can decline, '
              'but media messages will stay locked.',
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

/// Process-wide gate used by the chat widgets.
///
/// Swappable so tests can inject a fake (see [ReactionConsentGate]).
ReactionConsentGate reactionConsentGate = ReactionConsentGate();
