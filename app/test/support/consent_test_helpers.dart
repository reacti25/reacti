// Shared helpers for tests that exercise the DG1 capture-point gate.
//
// The patent-flow harness needs the consent + camera-permission gate to PASS
// so the silent-record loop still fires. These helpers set the local consent
// mirror and swap the global cameraPermissionService for a fake, mirroring the
// `reactionRecorder` swap the harness already does. Requires
// `initTestGetStorage()` to have registered the ConsentService first.

import 'package:reacti_app/features/consent/data/camera_permission_service.dart';
import 'package:reacti_app/features/consent/data/consent_service.dart';
import 'package:reacti_app/helpers/di.dart';

/// CameraPermissionService fake with a fixed grant state — never touches a real
/// OS platform channel.
class FakeCameraPermissionService extends CameraPermissionService {
  FakeCameraPermissionService({this.granted = true});

  /// Whether the camera is reported as permitted.
  bool granted;

  /// How many times [request] was called.
  int requestCalls = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requestCalls++;
    return granted;
  }
}

/// Marks the local consent mirror as consented (a fixed ISO-8601 timestamp).
void setTestConsent() =>
    locator<ConsentService>().syncFromServer('2026-06-13T00:00:00.000Z');

/// Clears the local consent mirror (the not-consented state).
void clearTestConsent() => locator<ConsentService>().syncFromServer(null);
