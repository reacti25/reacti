import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/helpers/permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/permission_item.dart';

/// Screen listing the app's runtime permissions and their grant status.
///
/// Each row shows whether a permission is granted or denied; tapping the
/// settings icon on a denied permission triggers a request.
class PermissionListScreen extends StatefulWidget {
  /// Creates the permissions list screen.
  const PermissionListScreen({super.key});

  @override
  State<PermissionListScreen> createState() => _PermissionListScreenState();
}

/// State for [PermissionListScreen]; loads and renders the permission list.
class _PermissionListScreenState extends State<PermissionListScreen> {
  /// Future resolving to the app's permissions and their current statuses.
  late Future<List<PermissionItem>> _permissions;

  /// Loads the permission list once when the screen is created.
  @override
  void initState() {
    super.initState();
    _permissions = PermissionHelper().getPermissions();
  }

  /// Builds the scaffold: an app bar and a [FutureBuilder] rendering each
  /// permission with its status and a request action for denied ones.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Permissions List')),
      body: FutureBuilder<List<PermissionItem>>(
        future: _permissions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No permissions available.'));
          }

          List<PermissionItem> permissionItems = snapshot.data!;

          return ListView.builder(
            itemCount: permissionItems.length,
            itemBuilder: (context, index) {
              PermissionItem permissionItem = permissionItems[index];
              return ListTile(
                title: Text(
                  permissionItem.name,
                  style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  permissionItem.status.isGranted ? "Granted" : "Denied",
                  style: TextStyle(
                    color:
                        permissionItem.status.isGranted
                            ? Colors.green
                            : Colors.red,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () async {
                    // Request the permission if it's denied
                    if (!permissionItem.status.isGranted) {
                      PermissionStatus status =
                          await permissionItem.permission.request();
                      setState(() {
                        permissionItem.status = status;
                      });
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
