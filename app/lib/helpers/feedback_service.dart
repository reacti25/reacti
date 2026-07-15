import 'package:flutter/services.dart';

/// Central, toggle-able haptic feedback for chat send/receive.
///
/// A light tap on send and a subtle tick on a genuinely-new inbound message,
/// gated by a single user setting (see `kKeySoundHapticsEnabled`). Uses only
/// [HapticFeedback] from `package:flutter/services.dart`, so it needs no extra
/// dependency, and keeps the platform call behind one place so it's easy to
/// stub in tests.
///
/// Deliberately NOT wired into the patented silent front-camera capture: no
/// feedback fires when a recipient's reaction is recorded, so that flow stays
/// silent.
class FeedbackService {
  FeedbackService._();

  /// Whether feedback is currently enabled; seeded from the stored setting at
  /// startup and updated live by the settings toggle.
  static bool _enabled = true;

  /// Enables or disables all feedback.
  static void setEnabled(bool value) => _enabled = value;

  /// Whether feedback is currently enabled.
  static bool get isEnabled => _enabled;

  /// A light tap when the user sends a message.
  static void messageSent() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// A subtle tick when a new inbound message/reaction arrives.
  static void messageReceived() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }
}
