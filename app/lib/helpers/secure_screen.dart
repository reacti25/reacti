import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps one-time media out of screenshots.
///
/// While anything [hold]s it, screenshots and screen recordings of the app
/// come out blank: on Android through the window's `FLAG_SECURE`, which also
/// blanks the app in the recent-apps view (MainActivity.kt); on an iPhone,
/// which has no such switch, by drawing the app inside a password field's
/// layer, as WhatsApp's view-once does (AppDelegate.swift). An iPhone still
/// reports each attempt through [screenshots], and the chat tells the sender.
///
/// Counted, so two one-time bubbles on screen at once keep the block on
/// until both have let go. Fails safe like [CallStatus]: off the phones, or
/// with no native side, every call is a no-op and never throws.
class SecureScreen {
  /// [onPhone] defaults to the real platform; tests pass false (no channel).
  SecureScreen({bool? onPhone})
    : _onPhone = onPhone ?? (Platform.isIOS || Platform.isAndroid) {
    if (_onPhone) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'screenshot') _screenshots.add(null);
      });
    }
  }

  static const _channel = MethodChannel('reacti/secure_screen');
  final bool _onPhone;
  final _screenshots = StreamController<void>.broadcast();

  /// How many one-time bubbles hold the block right now.
  int _holds = 0;

  /// Whether screenshots are being blocked (Android) or watched for (iPhone).
  bool get isOn => _holds > 0;

  /// One event per screenshot taken while the app is open (iPhone only:
  /// Android does not report them). While [isOn] the screenshot is blank.
  Stream<void> get screenshots => _screenshots.stream;

  /// Turns the block on, or keeps it on for one more holder.
  void hold() {
    if (_holds++ == 0) _set(true);
  }

  /// Lets go of one [hold]; the block turns off when nobody holds it.
  void release() {
    if (_holds == 0) return;
    if (--_holds == 0) _set(false);
  }

  /// Tells the native side. Fire and forget: a failure only means no block.
  void _set(bool on) {
    if (!_onPhone) return;
    _channel.invokeMethod<void>('setSecure', on).catchError((_) {});
  }

  /// Plays a screenshot being taken, for tests.
  @visibleForTesting
  void debugScreenshot() => _screenshots.add(null);
}

/// Shared [SecureScreen]; tests reassign it, like `callStatus`.
SecureScreen secureScreen = SecureScreen();
