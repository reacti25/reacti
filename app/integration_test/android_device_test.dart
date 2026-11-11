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

import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/logic/selfie_mirror.dart';
import 'package:reacti_app/features/chat/presentation/widget/picked_media_review_screen.dart';

import 'package:video_compress/video_compress.dart';

import 'support/wait.dart';

/// One front-camera recording: a still taken while it ran, and a frame of the
/// recorded video. The still is never mirrored, so it is the reference the
/// video frame is judged against.
typedef _SelfieSample = ({img.Image still, img.Image frame});

/// Records a two-second front-camera clip the way the camera screen does, with
/// front-video mirroring switched to [mirrored] while the camera is built.
Future<_SelfieSample> _recordSelfie({required bool mirrored}) async {
  final front = (await availableCameras()).firstWhere(
    (c) => c.lensDirection == CameraLensDirection.front,
  );
  final controller = CameraController(
    front,
    ResolutionPreset.high,
    enableAudio: true,
  );
  await setFrontVideoMirrored(mirrored);
  try {
    await controller.initialize();
  } finally {
    await setFrontVideoMirrored(false);
  }
  try {
    await controller.startVideoRecording();
    await Future<void>.delayed(const Duration(seconds: 1));
    final still = await controller.takePicture();
    await Future<void>.delayed(const Duration(seconds: 1));
    final clip = await controller.stopVideoRecording();
    expect(await File(clip.path).length(), greaterThan(0));
    final frame = await VideoCompress.getByteThumbnail(clip.path, quality: 90);
    expect(frame, isNotNull, reason: 'the clip must decode to a frame');
    return (
      still: img.bakeOrientation(img.decodeJpg(await still.readAsBytes())!),
      frame: img.decodeJpg(frame!)!,
    );
  } finally {
    await controller.dispose();
  }
}

/// Mean brightness difference (0 to 255) between [a] and [b], both shrunk to
/// the same small grid so only the layout of the scene counts.
double _difference(img.Image a, img.Image b) {
  final small = [
    for (final image in [a, b])
      img.grayscale(img.copyResize(image, width: 36, height: 64)),
  ];
  var total = 0.0;
  for (final pixel in small[0]) {
    total += (pixel.r - small[1].getPixel(pixel.x, pixel.y).r).abs();
  }
  return total / (36 * 64);
}

/// TEMPORARY diagnostic: prints [image] into the test log as base64 so the
/// frames can be looked at once. Removed before merge.
void _dump(String name, img.Image image) {
  final data = base64Encode(
    img.encodeJpg(img.copyResize(image, width: 200), quality: 70),
  );
  const size = 700;
  final parts = (data.length / size).ceil();
  for (var i = 0; i < parts; i++) {
    final end = (i + 1) * size > data.length ? data.length : (i + 1) * size;
    // ignore: avoid_print
    print('SELFIE_DIAG $name $i/$parts ${data.substring(i * size, end)}');
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

  testWidgets('a selfie video is recorded mirrored, like the preview', (
    tester,
  ) async {
    for (final mirrored in [false, true]) {
      final sample = await _recordSelfie(mirrored: mirrored);
      final same = _difference(sample.frame, sample.still);
      final flipped = _difference(
        sample.frame,
        img.flipHorizontal(sample.still.clone()),
      );
      // ignore: avoid_print
      print(
        'SELFIE_DIAG metrics mirrored=$mirrored same=$same flipped=$flipped '
        'still=${sample.still.width}x${sample.still.height} '
        'frame=${sample.frame.width}x${sample.frame.height}',
      );
      _dump('still_$mirrored', sample.still);
      _dump('frame_$mirrored', sample.frame);
    }
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
