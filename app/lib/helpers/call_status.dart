import 'dart:io';

import 'package:flutter/services.dart';

/// Shown when a sealed media is tapped during a call. No em dashes.
const kInCallOpenMessage =
    "You're on a call. Open this after the call so your reaction can be recorded.";

/// Tells whether the phone is in a call right now: a regular call, or a
/// WhatsApp, FaceTime or other VoIP call.
///
/// Why: a call holds the microphone, so a silent reaction recorded during
/// one comes out empty and the server rejects the upload. The receiver
/// widget asks this before opening sealed media.
///
/// iOS answers from CallKit (`CXCallObserver`), Android from the audio mode
/// (`MODE_IN_CALL` / `MODE_IN_COMMUNICATION`); see AppDelegate.swift and
/// MainActivity.kt. Fails open: any error (no channel in tests, an older
/// native build) reads as "not in a call", so this check can never be the
/// reason media will not open.
class CallStatus {
  /// [onPhone] defaults to the real platform; tests pass true to reach the channel.
  CallStatus({bool? onPhone})
    : _onPhone = onPhone ?? (Platform.isIOS || Platform.isAndroid);

  static const _channel = MethodChannel('reacti/call_status');
  final bool _onPhone;

  /// True while any call is active or ringing; false otherwise or on error.
  Future<bool> isInCall() async {
    // Only the phones have the native side; anywhere else (the test host)
    // a channel call would never be answered.
    if (!_onPhone) return false;
    try {
      // The timeout is a belt: a native side that never answered would
      // otherwise leave sealed media unopenable.
      return await _channel
              .invokeMethod<bool>('isInCall')
              .timeout(const Duration(seconds: 1)) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

/// Shared [CallStatus]; tests reassign it to a fake, like `reactionRecorder`.
CallStatus callStatus = CallStatus();
