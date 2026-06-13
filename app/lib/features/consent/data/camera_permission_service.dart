import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper over the OS camera-permission status/request for the DG1
/// capture-point gate.
///
/// Exists so the patent-flow widget can ask "is the camera permitted?" and
/// "request it" without taking a direct dependency on `permission_handler`,
/// and so tests can swap [cameraPermissionService] for a fake that never
/// touches a real platform channel (mirroring the `reactionRecorder` pattern).
class CameraPermissionService {
  /// Whether camera permission is currently granted by the OS.
  Future<bool> isGranted() async =>
      Permission.camera.status.then((status) => status.isGranted);

  /// Prompts the user for camera permission and returns whether it ended up
  /// granted. A no-op grant if it was already granted.
  Future<bool> request() async =>
      Permission.camera.request().then((status) => status.isGranted);
}

/// Shared [CameraPermissionService] used by the capture-point consent gate.
///
/// Global instance mirroring the `reactionRecorder` singleton pattern so the
/// receiver-message widget can consult it without constructor injection.
/// Tests reassign this to a fake.
CameraPermissionService cameraPermissionService = CameraPermissionService();
