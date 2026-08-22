import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/presentation/camera_capture_screen.dart';

/// Builds a [CameraDescription] with the given [lens]; name/orientation are
/// irrelevant to lens-direction selection so they get filler values.
CameraDescription _cam(CameraLensDirection lens, [String name = 'cam']) =>
    CameraDescription(name: name, lensDirection: lens, sensorOrientation: 0);

void main() {
  group('oppositeLensCameraIndex', () {
    test('flips from a back camera to the front camera', () {
      final cameras = [
        _cam(CameraLensDirection.back),
        _cam(CameraLensDirection.front),
      ];
      expect(oppositeLensCameraIndex(cameras, 0), 1);
    });

    test('flips from the front camera back to a rear camera', () {
      final cameras = [
        _cam(CameraLensDirection.back),
        _cam(CameraLensDirection.front),
      ];
      expect(oppositeLensCameraIndex(cameras, 1), 0);
    });

    test('skips auxiliary rear lenses and lands on the front camera', () {
      // Regression: a phone exposing wide + tele + depth rear lenses before
      // the front camera must not stop on another rear lens (the old
      // (i+1) % n step did, wedging the switch).
      final cameras = [
        _cam(CameraLensDirection.back, 'main'),
        _cam(CameraLensDirection.back, 'ultrawide'),
        _cam(CameraLensDirection.back, 'tele'),
        _cam(CameraLensDirection.front, 'selfie'),
      ];
      expect(oppositeLensCameraIndex(cameras, 0), 3);
    });

    test('returns -1 when no camera faces the other way', () {
      final cameras = [
        _cam(CameraLensDirection.back, 'main'),
        _cam(CameraLensDirection.back, 'ultrawide'),
      ];
      expect(oppositeLensCameraIndex(cameras, 0), -1);
    });
  });

  group('nextFlashMode', () {
    test('a lens with a flash cycles Off → Auto → Always → Off', () {
      expect(nextFlashMode(FlashMode.off), FlashMode.auto);
      expect(nextFlashMode(FlashMode.auto), FlashMode.always);
      expect(nextFlashMode(FlashMode.always), FlashMode.off);
    });

    test('the front lens cycles Off → Always → Off, skipping Auto', () {
      // Auto cannot be honoured without an ambient-light reading, and there is
      // no lamp to delegate the decision to. A mode that silently does nothing
      // is worse than one that is not offered.
      expect(
        nextFlashMode(FlashMode.off, hasLensFlash: false),
        FlashMode.always,
      );
      expect(
        nextFlashMode(FlashMode.always, hasLensFlash: false),
        FlashMode.off,
      );
    });

    test('flipping to the front while on Auto lands on Off, not Always', () {
      // The mode survives the lens switch, so the next tap starts from a value
      // that is not in the front cycle at all. Landing on Always there would
      // whiteout the screen on a shot the user never asked to light.
      expect(nextFlashMode(FlashMode.auto, hasLensFlash: false), FlashMode.off);
    });
  });
}
