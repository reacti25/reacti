// Tests for ReactionRecorder.lastFailureReason — the additive field that lets
// the widget report a granular reaction_recorded.failure_reason instead of a
// flat null_clip. record()'s return type (and the patent flow) is unchanged.
//
// Under flutter test there is no camera platform channel, so record() fails
// fast; we assert it returns null AND classifies the failure into a known enum
// value rather than leaving the reason unset.

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';

void main() {
  const knownReasons = {
    'camera_unavailable',
    'permission_denied',
    'init_error',
    'recording_error',
    'other',
  };

  test('a failed recording returns null and classifies the reason', () async {
    final recorder = ReactionRecorder();

    final file = await recorder.record(
      minDuration: Duration.zero,
      maxDuration: Duration.zero,
    );

    expect(file, isNull);
    expect(recorder.lastFailureReason, isNotNull);
    expect(knownReasons.contains(recorder.lastFailureReason), isTrue);
  });

  group('pickReactionCamera', () {
    CameraDescription cam(String name, CameraLensDirection dir) =>
        CameraDescription(name: name, lensDirection: dir, sensorOrientation: 0);

    test('picks the front lens even when it is not last', () {
      // The Android bug: `cameras.last` would return the external camera here.
      final cameras = [
        cam('back', CameraLensDirection.back),
        cam('front', CameraLensDirection.front),
        cam('usb', CameraLensDirection.external),
      ];
      expect(pickReactionCamera(cameras)?.name, 'front');
    });

    test('picks the front lens when it is first', () {
      final cameras = [
        cam('front', CameraLensDirection.front),
        cam('back', CameraLensDirection.back),
      ];
      expect(pickReactionCamera(cameras)?.name, 'front');
    });

    test('returns null rather than filming the room with no front lens', () {
      final cameras = [
        cam('back', CameraLensDirection.back),
        cam('wide', CameraLensDirection.back),
      ];
      expect(pickReactionCamera(cameras), isNull);
    });

    test('returns null for an empty list', () {
      expect(pickReactionCamera(const []), isNull);
    });
  });
}
