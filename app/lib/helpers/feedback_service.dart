import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Central, toggle-able sound + vibration feedback for chat send/receive.
///
/// A light tap + soft "pop" on send and a subtle tick + gentle "pop-ding" on a
/// genuinely-new inbound message, gated by a single user setting (see
/// `kKeySoundHapticsEnabled`). Haptics use [HapticFeedback]; the short sounds
/// are bundled WAVs played via [AudioPlayer]. Everything is fire-and-forget and
/// wrapped so a platform/audio hiccup can never surface to the user or a test.
///
/// Deliberately NOT wired into the patented silent front-camera capture: no
/// feedback fires when a recipient's reaction is recorded, so that flow stays
/// silent.
class FeedbackService {
  FeedbackService._();

  /// Whether feedback is currently enabled; seeded from the stored setting at
  /// startup and updated live by the settings toggle.
  static bool _enabled = true;

  /// Whether to actually play the bundled sounds (vibration is unaffected).
  /// Set false in unit tests so the audio plugin — which throws an async
  /// MissingPluginException in the test harness — is never touched.
  static bool debugPlaySounds = true;

  /// Reused low-latency players for the two short sounds (lazily created so
  /// nothing touches the audio plugin until the first real playback).
  static AudioPlayer? _sendPlayer;
  static AudioPlayer? _receivePlayer;

  /// Enables or disables all feedback.
  static void setEnabled(bool value) => _enabled = value;

  /// Whether feedback is currently enabled.
  static bool get isEnabled => _enabled;

  /// A light tap + soft pop when the user sends a message.
  static void messageSent() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    if (!debugPlaySounds) return;
    _sendPlayer ??= _newPlayer();
    _play(_sendPlayer, 'sounds/send.wav');
  }

  /// A subtle tick + gentle chime when a new inbound message/reaction arrives.
  static void messageReceived() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    if (!debugPlaySounds) return;
    _receivePlayer ??= _newPlayer();
    _play(_receivePlayer, 'sounds/receive.wav');
  }

  /// Builds a low-latency player, tolerating a missing plugin (e.g. in tests).
  static AudioPlayer? _newPlayer() {
    try {
      return AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {
      return null;
    }
  }

  /// Plays [asset] on [player], swallowing any audio error so feedback is never
  /// allowed to interrupt the send/receive path.
  static void _play(AudioPlayer? player, String asset) {
    if (player == null) return;
    try {
      player.play(AssetSource(asset), volume: 0.5).catchError((_) {});
    } catch (_) {
      // Audio is a nicety — never let it throw into the chat flow.
    }
  }
}
