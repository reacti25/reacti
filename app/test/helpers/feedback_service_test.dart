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

  test('its sound players never track position (no endless redraws)', () async {
    // Stand in for the audio plugin so a real player can be built.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channels = ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global'];
    for (final name in channels) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    addTearDown(() {
      for (final name in channels) {
        messenger.setMockMethodCallHandler(MethodChannel(name), null);
      }
    });

    final player = FeedbackService.newPlayer()!;
    // Runs before the mocks come off (tear-downs run last-added first), so
    // the player's own async setup never hits a missing plugin.
    addTearDown(player.dispose);

    // Low-latency players never report completion, so a position updater
    // would schedule a frame every frame forever once a sound plays. Without
    // one the position stream is empty and ends at once.
    expect(
      await player.onPositionChanged.isEmpty.timeout(
        const Duration(seconds: 1),
      ),
      isTrue,
    );
  });
}
