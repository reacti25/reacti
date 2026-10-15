// Android device checks: runs on a real Android OS (the CI emulator, API 34,
// with an emulated front camera and microphone), not in the Dart test VM.
//
// Unit tests prove the logic; these prove the logic works through the real
// plugins on Android, which is where every "it works on iPhone" assumption
// breaks. Driven by .github/scripts/android_integration.sh, which grants the
// permissions from the host and plays the user's part in the system Photo
// Picker (it cannot be driven from Dart). Plan:
// docs/PLAN-android-and-play-store-2026-09-28.md, Steps 5 and 7.
//
// Run locally against an emulator:
//   flutter test integration_test/android_device_test.dart -d emulator-5554
// (grant CAMERA and RECORD_AUDIO yourself, and press Back in the picker).

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/presentation/widget/picked_media_review_screen.dart';

/// Polls [condition] until it holds, failing after [timeout].
Future<void> waitFor(
  Future<bool> Function() condition, {
  required String what,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Step 5: records a real clip from the front camera, with audio', (
    tester,
  ) async {
    // The host grants these right after install; never prompt here, because
    // nobody is at the emulator to answer.
    await waitFor(
      () async =>
          await Permission.camera.isGranted &&
          await Permission.microphone.isGranted,
      what: 'camera and microphone to be granted by the host',
    );

    final cameras = await availableCameras();
    expect(
      cameras.map((c) => c.lensDirection),
      contains(CameraLensDirection.front),
      reason: 'the emulator must expose a front camera',
    );
    expect(
      pickReactionCamera(cameras)?.lensDirection,
      CameraLensDirection.front,
    );

    // The exact call the patent flow makes, shortened from 4s to 2s.
    final recorder = ReactionRecorder();
    final clip = await recorder.record(
      minDuration: const Duration(seconds: 2),
      maxDuration: const Duration(seconds: 2),
    );
    expect(recorder.lastFailureReason, isNull);
    expect(clip, isNotNull);
    expect(await File(clip!.path).length(), greaterThan(0));
  });

  testWidgets('Step 7: the gallery opens the system Photo Picker', (
    tester,
  ) async {
    enableAndroidPhotoPicker(); // what main() does

    // The host sees the picker open, checks no permission prompt came first,
    // then presses Back, so the pick returns nothing. A missing photo picker
    // (or a permission prompt in its place) never resolves this future.
    final files = await ImagePicker()
        .pickMultipleMedia(limit: 30)
        .timeout(const Duration(seconds: 120));
    expect(files, isEmpty);
  });
}
