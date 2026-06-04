import 'package:permission_handler/permission_handler.dart';

/// View model pairing a runtime [Permission] with its display name and
/// current grant [status].
///
/// Used by the permissions list screen to render each permission row and to
/// reflect status changes after a request.
class PermissionItem {
  /// Human-readable label for the permission (e.g. "Camera").
  final String name;

  /// The underlying platform permission this item represents.
  final Permission permission;

  /// The current grant status; mutable so it can be updated after a request.
  PermissionStatus status;

  /// Creates a [PermissionItem] with the required [name], [permission] and
  /// initial [status].
  PermissionItem({
    required this.name,
    required this.permission,
    required this.status,
  });
}
