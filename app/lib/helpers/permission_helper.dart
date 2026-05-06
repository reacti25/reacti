import 'package:achiar_expert_app/features/permission/model/permission_item.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  Future<List<PermissionItem>> getPermissions() async {
    // List of permissions you need to check
    List<Permission> permissions = [
      Permission.camera,
      Permission.contacts,
      Permission.microphone,
      Permission.photos,
      Permission.location,
      // Add other permissions as needed
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
      case Permission.location:
        return "Location";
      default:
        return "Unknown Permission";
    }
  }
}
