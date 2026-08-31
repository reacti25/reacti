/// Emits `permission_result` when an OS permission dialog returns an answer.
///
/// This exists because a refused permission and a disinterested user look
/// identical in every other number the app reports. Someone who taps "Don't
/// Allow" on the camera cannot send a reaction at all, and until now they were
/// counted alongside people who simply chose not to.
///
/// Nothing here identifies anyone: the event carries which permission was
/// asked for and what the answer was, and nothing else. It never records what
/// the permission then gave access to (no contacts, no captured media).
library;

import 'package:permission_handler/permission_handler.dart';

import '../constants/app_constants.dart';
import '../helpers/di.dart';
import 'activation_funnel.dart';
import 'analytics_locator.dart';
import 'events.dart';

/// Permission names as they appear on the wire.
///
/// Deliberately our own strings rather than a platform enum: iOS and Android
/// spell these differently, and a dashboard should not have to know that.
class Permissions {
  Permissions._();

  /// The front camera the reaction is recorded with.
  static const String camera = 'camera';

  /// The microphone recorded alongside it.
  static const String microphone = 'microphone';

  /// Push notifications, the path that brings someone back.
  static const String notifications = 'notifications';

  /// The address book, used to find friends already on Reacti.
  static const String contacts = 'contacts';
}

/// Maps a `permission_handler` [status] to the catalog's `result` enum.
///
/// [status] may be null when the plugin returns no entry for a permission it
/// was asked about, which is reported as `unknown` rather than guessed at.
///
/// Returns one of `granted`, `limited`, `provisional`, `permanently_denied`,
/// `restricted`, `denied` or `unknown`. `limited` and `provisional` are kept
/// separate from `granted` because a partial grant behaves differently in
/// practice, and folding them together would hide that.
String permissionResultOf(PermissionStatus? status) {
  switch (status) {
    case PermissionStatus.granted:
      return 'granted';
    case PermissionStatus.limited:
      return 'limited';
    case PermissionStatus.provisional:
      return 'provisional';
    case PermissionStatus.permanentlyDenied:
      return 'permanently_denied';
    case PermissionStatus.restricted:
      return 'restricted';
    case PermissionStatus.denied:
      return 'denied';
    case null:
      return 'unknown';
  }
}

/// Reports the answer to one permission dialog. Fire-and-forget.
///
/// [permission] is one of the [Permissions] constants; [result] is a value
/// from [permissionResultOf], or the caller's own mapping when the answer did
/// not come from `permission_handler` (push permission comes from Firebase).
///
/// Emits only when the answer **differs from the last one reported** for that
/// permission. A change of mind is the interesting event and still fires; an
/// unchanged answer is not. This matters because the push permission is
/// re-requested on every launch and returns the standing answer without
/// showing a dialog, so reporting every call would make this the app's
/// chattiest event while adding nothing.
///
/// Reading a current state from these events therefore means taking each
/// person's latest answer, which is what
/// `scripts/analytics/growth_digest.py` does.
void trackPermissionResult(String permission, String result) {
  try {
    if (_lastReported(permission) == result) return;
    final elapsed = ActivationFunnel.msSinceFirstLaunch();
    analytics.track(Events.permissionResult, {
      Props.permission: permission,
      Props.result: result,
      if (elapsed != null) Props.msSinceFirstLaunch: elapsed,
    });
    appData.write('$kKeyPermissionReported:$permission', result);
  } catch (_) {
    // Every call site sits in front of a permission dialog on a real user
    // path. Measurement must never be the thing that breaks one.
  }
}

/// The last answer reported for [permission], or null when none is recorded.
///
/// Null on an unreadable store as well, so a storage failure means the event
/// is emitted rather than silently swallowed: a duplicate is cheap, a missing
/// permission answer is the thing this whole file exists to prevent.
String? _lastReported(String permission) {
  try {
    final value = appData.read('$kKeyPermissionReported:$permission');
    return value is String ? value : null;
  } catch (_) {
    return null;
  }
}

/// Reports a `permission_handler` result directly.
///
/// Convenience for the call sites that already hold a [PermissionStatus].
void trackPermissionStatus(String permission, PermissionStatus? status) =>
    trackPermissionResult(permission, permissionResultOf(status));
