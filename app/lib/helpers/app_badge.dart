import 'dart:developer';

import 'package:app_badge_plus/app_badge_plus.dart';

/// Sets the app-icon unread badge, fail-safe.
///
/// Thin wrapper over [AppBadgePlus] so the call site never has to care whether
/// the platform supports badges or whether the plugin throws — a badge is
/// cosmetic and must never break the app. A [count] of 0 clears the badge.
class AppBadge {
  /// Updates the icon badge to [count] (0 clears it). Never throws.
  static Future<void> set(int count) async {
    try {
      if (await AppBadgePlus.isSupported()) {
        AppBadgePlus.updateBadge(count);
      }
    } catch (e) {
      // A cosmetic badge must never surface as an error.
      log('AppBadge.set failed: $e');
    }
  }
}
