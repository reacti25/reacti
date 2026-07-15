// Unit tests for FeedbackService — verifies the _enabled guard actually gates
// the platform haptic call, so the settings toggle really silences feedback.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/helpers/feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // HapticFeedback goes through SystemChannels.platform as 'HapticFeedback.vibrate';
  // record those calls to prove the guard.
  final calls = <String>[];

  setUp(() {
    calls.clear();
    // Keep the audio plugin (unavailable in tests) untouched; we're only
    // asserting the vibration guard here.
    FeedbackService.debugPlaySounds = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    FeedbackService.setEnabled(true);
    FeedbackService.debugPlaySounds = true;
  });

  test('fires haptics when enabled', () async {
    FeedbackService.setEnabled(true);
    FeedbackService.messageSent();
    FeedbackService.messageReceived();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isNotEmpty);
  });

  test('stays silent when disabled', () async {
    FeedbackService.setEnabled(false);
    FeedbackService.messageSent();
    FeedbackService.messageReceived();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
  });
}
