import 'package:flutter/foundation.dart';
import 'package:reacti_app/features/permission/model/permission_item.dart';
import 'package:permission_handler/permission_handler.dart';

/// Queries the OS for the status of the runtime permissions the app uses.
///
/// Backs the permission-list screen, turning raw [Permission] values into
/// display-ready [PermissionItem] models with human-readable names.
class PermissionHelper {
  /// Returns the current status of each app-relevant runtime permission.
  ///
  /// Iterates the camera, contacts, microphone and (except on Android) photos
  /// permissions, pairing each with its current [PermissionStatus] and a
  /// readable label via [_getPermissionName].
  Future<List<PermissionItem>> getPermissions() async {
    // List of permissions you need to check
    List<Permission> permissions = [
      Permission.camera,
      Permission.contacts,
      Permission.microphone,
      // Android picks media through the system Photo Picker, which needs no
      // permission (the app no longer declares one), so a Photos row there
      // would read "denied" forever and lead nowhere.
      if (defaultTargetPlatform != TargetPlatform.android) Permission.photos,
    ];

    // Get the status for each permission
    List<PermissionItem> permissionItems = [];

    for (var permission in permissions) {
      PermissionStatus status = await permission.status;
      permissionItems.add(
        PermissionItem(
          name: _getPermissionName(permission),
          permission: permission,
          status: status,
        ),
      );
    }

    return permissionItems;
  }

  /// Maps a [permission] to a user-facing display name.
  ///
  /// Returns `"Unknown Permission"` for any permission not explicitly handled.
  // Helper method to get a human-readable name for the permission
  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return "Camera";
      case Permission.contacts:
        return "Contacts";
      case Permission.microphone:
        return "Microphone";
      case Permission.photos:
        return "Photos";
      default:
        return "Unknown Permission";
    }
  }
}
