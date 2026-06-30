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

/// Captures the silent front-camera reaction clip for the patent flow.
///
/// Wraps the `camera` plugin behind a single [record] call so the
/// recording step can be faked in tests without booting real hardware.
/// The receiver-message widget invokes this after a media message is
/// opened; the resulting clip is uploaded as a `type: "reaction"`
/// message. Re-entry is guarded so a single recording can be in flight
/// at a time.
class ReactionRecorder {
  /// Whether a recording is currently in progress.
  ///
  /// Used as a re-entry guard so a second [record] call is dropped
  /// while the first clip is still being captured.
  bool _isRecording = false;

  /// Why the most recent [record] call returned null, for analytics:
  /// `camera_unavailable` | `permission_denied` | `init_error` |
  /// `recording_error` | `other`, or null when the last call succeeded.
  ///
  /// Observability only — set as a side effect so [record]'s return type
  /// (and the patent flow) stays unchanged. The widget reads it to enrich
  /// the `reaction_recorded` failure reason.
  String? lastFailureReason;

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
    Duration minDuration = const Duration(seconds: 4),
    Duration maxDuration = const Duration(seconds: 4),
    Future<void>? stopEarly,
  }) async {
    if (_isRecording) return null;
    _isRecording = true;
    lastFailureReason = null;
    CameraController? controller;
    // Which phase we are in, so a thrown CameraException maps to init_error vs
    // recording_error.
    var stage = 'init';
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        lastFailureReason = 'camera_unavailable';
        return null;
      }

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
      stage = 'record';
      await controller.startVideoRecording();
      log('Recording started...');

      await reactionRecordWindow(
        minDuration: minDuration,
        maxDuration: maxDuration,
        stopEarly: stopEarly,
      );

      final file = await controller.stopVideoRecording();
      log('Recording stopped at ${file.path}');
      return file;
    } on CameraException catch (e) {
      lastFailureReason = _classifyCameraException(e, stage);
      log('⚠️ Error while recording video: $e');
      return null;
    } catch (e) {
      lastFailureReason = 'other';
      log('⚠️ Error while recording video: $e');
      return null;
    } finally {
      if (controller != null) {
        await controller.dispose();
      }
      _isRecording = false;
    }
  }

  /// Maps a [CameraException] to a `reaction_recorded` failure reason:
  /// `permission_denied` when the code signals a denied/blocked permission,
  /// otherwise `init_error` (thrown during setup) or `recording_error`
  /// (thrown once recording had started), based on [stage].
  String _classifyCameraException(CameraException e, String stage) {
    final code = e.code.toLowerCase();
    if (code.contains('permission') ||
        code.contains('denied') ||
        code.contains('access')) {
      return 'permission_denied';
    }
    return stage == 'init' ? 'init_error' : 'recording_error';
  }
}

/// Shared [ReactionRecorder] used by the receiver-message widget.
///
/// Global recorder instance. Mirrors the rx_* singleton pattern used
/// elsewhere in the app (sendMessageRx, viewInboxImageRx, …) so the
/// widget can call `reactionRecorder.record()` without taking a
/// dependency via constructor. Tests reassign this to a fake.
ReactionRecorder reactionRecorder = ReactionRecorder();

/// How long the silent reaction keeps recording: at least [minDuration], at
/// most [maxDuration], stopping as soon as [stopEarly] fires (the viewer
/// stopped watching) — but never before the floor. Completes when recording
/// should stop. Extracted so the window is unit-testable without a camera.
///
/// For a video reaction the caller passes 5s/20s and a future that completes
/// when the video ends, is paused, or the viewer leaves — giving a reaction
/// clamped to the actual watch length. For images min==max so it's a fixed clip.
Future<void> reactionRecordWindow({
  required Duration minDuration,
  required Duration maxDuration,
  Future<void>? stopEarly,
}) async {
  await Future<void>.delayed(minDuration);
  final remaining = maxDuration - minDuration;
  if (remaining <= Duration.zero) return;
  if (stopEarly == null) {
    await Future<void>.delayed(remaining);
  } else {
    await Future.any([stopEarly, Future<void>.delayed(remaining)]);
  }
}
