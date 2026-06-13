import 'package:flutter/material.dart';

import '../../../constants/text_font_style.dart';
import '../../../helpers/di.dart';
import '../consent_copy.dart';
import '../data/camera_permission_service.dart';
import '../data/consent_service.dart';

/// Capture-point consent + camera-permission gate for the patent flow (DG1 F3).
///
/// Returns whether the silent reaction-recording loop may proceed. This MUST be
/// awaited and pass **before** `mark-viewed` and any recording — the patent
/// path never records first and asks later.
///
/// Decision:
/// - **Already consented and permitted** → returns `true` with no interruption
///   (the common, unchanged path for accepting users).
/// - **Missing either** → shows a pop-up explaining the feature with
///   placeholder copy. "Cancel" returns `false` (media stays blurred/unviewed,
///   nothing recorded). "Enable" records consent on the server (if not already)
///   and requests OS camera permission; it returns `true` only if both end up
///   satisfied, else `false`.
///
/// [consentService] and [permissionService] default to the shared singletons
/// ([locator]'s [ConsentService] and the global [cameraPermissionService]) and
/// are injectable for tests.
Future<bool> ensureRecordingConsentAndPermission(
  BuildContext context, {
  ConsentService? consentService,
  CameraPermissionService? permissionService,
}) async {
  final consent = consentService ?? locator<ConsentService>();
  final permission = permissionService ?? cameraPermissionService;

  // Fast path: consented and permitted → proceed silently, exactly as before
  // the gate existed.
  if (consent.hasConsented && await permission.isGranted()) {
    return true;
  }

  // The async permission check above crossed a frame; bail if the widget that
  // owns this context went away in the meantime.
  if (!context.mounted) return false;

  final wantsToEnable = await _showConsentGateDialog(context);
  if (wantsToEnable != true) {
    // Cancelled or dismissed — do not view, do not record.
    return false;
  }

  // Record consent server-side first (the source of truth); abort if it could
  // not be persisted so we never record against unproven consent.
  if (!consent.hasConsented) {
    final granted = await consent.grantConsent();
    if (!granted) return false;
  }

  // Finally the OS camera permission: without it the reaction cannot be
  // captured, so a denial blocks the flow just like a cancel.
  return permission.request();
}

/// Shows the capture-point consent/permission pop-up and resolves to the user's
/// choice: `true` to enable, `false`/`null` to cancel.
Future<bool?> _showConsentGateDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(
            'Enable reactions?',
            style: TextFontStyle.headline16w500C333333Poppins,
          ),
          // Scrollable so the disclosure never overflows on small screens.
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Placeholder disclosure — final wording is a release gate.
                Text(
                  kConsentCopyPlaceholder,
                  style: TextFontStyle.headline14w400C666666Poppins,
                ),
                const SizedBox(height: 12),
                Text(
                  kConsentFeatureBlurb,
                  style: TextFontStyle.headline14w400C666666Poppins,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('consent_gate_cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('consent_gate_enable'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Enable'),
            ),
          ],
        ),
  );
}
