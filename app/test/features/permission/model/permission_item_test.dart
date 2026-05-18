// Unit tests for the `PermissionItem` view model.
//
// `PermissionItem` is a plain value class (not a JSON DTO): it pairs a
// runtime `Permission` with a display name and a mutable grant status.
// These tests pin the constructor wiring and the mutability of `status`.

import 'package:achiar_expert_app/features/permission/model/permission_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('PermissionItem', () {
    test('constructor stores name, permission and initial status', () {
      final item = PermissionItem(
        name: 'Camera',
        permission: Permission.camera,
        status: PermissionStatus.denied,
      );

      expect(item.name, 'Camera');
      expect(item.permission, Permission.camera);
      expect(item.status, PermissionStatus.denied);
    });

    test('status is mutable and can be updated after construction', () {
      final item = PermissionItem(
        name: 'Microphone',
        permission: Permission.microphone,
        status: PermissionStatus.denied,
      );

      item.status = PermissionStatus.granted;

      expect(item.status, PermissionStatus.granted);
      // The other fields are unaffected by the status change.
      expect(item.name, 'Microphone');
      expect(item.permission, Permission.microphone);
    });

    test('two items can carry distinct permissions and statuses', () {
      final camera = PermissionItem(
        name: 'Camera',
        permission: Permission.camera,
        status: PermissionStatus.granted,
      );
      final storage = PermissionItem(
        name: 'Storage',
        permission: Permission.storage,
        status: PermissionStatus.permanentlyDenied,
      );

      expect(camera.permission, isNot(equals(storage.permission)));
      expect(camera.status, PermissionStatus.granted);
      expect(storage.status, PermissionStatus.permanentlyDenied);
    });

    test('mutating one item does not affect another', () {
      final a = PermissionItem(
        name: 'A',
        permission: Permission.camera,
        status: PermissionStatus.denied,
      );
      final b = PermissionItem(
        name: 'B',
        permission: Permission.microphone,
        status: PermissionStatus.denied,
      );

      a.status = PermissionStatus.granted;

      expect(a.status, PermissionStatus.granted);
      expect(b.status, PermissionStatus.denied);
    });
  });
}
