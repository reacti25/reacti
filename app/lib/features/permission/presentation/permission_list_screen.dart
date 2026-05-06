import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/permission_item.dart';

class PermissionListScreen extends StatefulWidget {
  const PermissionListScreen({super.key});

  @override
  State<PermissionListScreen> createState() => _PermissionListScreenState();
}

class _PermissionListScreenState extends State<PermissionListScreen> {
  late Future<List<PermissionItem>> _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = PermissionHelper().getPermissions();
  }

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
                  style: TextFontStyle.headline16w500CFFFFFFPoppins,
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
                  icon: Icon(Icons.settings, color: AppColors.cFFFFFF),
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
