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
}
