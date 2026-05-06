import 'package:permission_handler/permission_handler.dart';

class PermissionItem {
  final String name;
  final Permission permission;
  PermissionStatus status;

  PermissionItem({
    required this.name,
    required this.permission,
    required this.status,
  });
}
