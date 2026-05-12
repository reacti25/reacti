// Reaction recorder — the camera part of the patent flow.
//
// This class wraps the `camera` plugin so the recording step is
// testable without booting a real camera. The receiver-message widget
// calls `reactionRecorder.record()`; tests swap the global instance
// with a fake that returns a canned XFile.
//
// Behaviour mirrors the original inline `recordVideoSilently()` method
// that used to live on _ReceiverMessageWidgetState (see git history
// before this file existed):
//
//   1. ask the camera plugin for available cameras
//   2. pick the front camera (iOS) or the "last" camera (Android)
//   3. initialise + startVideoRecording
//   4. wait `duration` (default 4s)
//   5. stopVideoRecording, return the file
//
// Re-entry is guarded by `_isRecording` — a second tap while the first
// recording is still running is dropped on the floor, so the user
// can't accidentally fire two recordings.

import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';

class ReactionRecorder {
  bool _isRecording = false;

  /// Records a short front-camera clip and returns the resulting file.
  ///
  /// Returns `null` if:
  ///   - the device has no cameras
  ///   - a recording is already in progress
  ///   - anything in the camera plugin throws (logged, swallowed)
  ///
  /// [duration] is exposed for tests so they don't have to wait the
  /// production 4 seconds.
  Future<XFile?> record({
    Duration duration = const Duration(seconds: 4),
  }) async {
    if (_isRecording) return null;
    _isRecording = true;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;

      // iOS: front camera lensDirection match.
      // Android: cameras.last is the convention used by the original code.
      CameraDescription camera;
      if (Platform.isIOS) {
        camera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
      } else {
        camera = cameras.last;
      }

      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await controller.initialize();
      await controller.startVideoRecording();
      log('Recording started...');

      await Future.delayed(duration);

      final file = await controller.stopVideoRecording();
      log('Recording stopped at ${file.path}');
      return file;
    } catch (e) {
      log('⚠️ Error while recording video: $e');
      return null;
    } finally {
      if (controller != null) {
        await controller.dispose();
      }
      _isRecording = false;
    }
  }
}

/// Global recorder instance. Mirrors the rx_* singleton pattern used
/// elsewhere in the app (sendMessageRx, viewInboxImageRx, …) so the
/// widget can call `reactionRecorder.record()` without taking a
/// dependency via constructor. Tests reassign this to a fake.
ReactionRecorder reactionRecorder = ReactionRecorder();
