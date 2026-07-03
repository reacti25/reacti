import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/helpers/permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/permission_item.dart';

/// Screen listing the app's runtime permissions and their live grant status.
///
/// Each row shows the current status (Granted / Limited / Denied). Tapping the
/// gear requests the permission the first time it's asked, and otherwise opens
/// the OS app-settings — iOS never re-prompts in-app once a choice is made. The
/// list re-reads on resume, so changes made in Settings are reflected on return.
class PermissionListScreen extends StatefulWidget {
  /// Creates the permissions list screen.
  const PermissionListScreen({super.key});

  @override
  State<PermissionListScreen> createState() => _PermissionListScreenState();
}

/// State for [PermissionListScreen]; loads and renders the permission list.
class _PermissionListScreenState extends State<PermissionListScreen>
    with WidgetsBindingObserver {
  /// Future resolving to the app's permissions and their current statuses.
  late Future<List<PermissionItem>> _permissions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-read statuses when returning to the app (e.g. from iOS Settings), so
  /// the list never shows stale values.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  void _load() {
    setState(() => _permissions = PermissionHelper().getPermissions());
  }

  /// Requests the permission the first time; otherwise opens app settings
  /// (iOS won't re-prompt once decided). Refreshes the list afterwards.
  Future<void> _onTap(PermissionItem item) async {
    final status = await item.permission.status;
    if (status.isGranted || status.isLimited) {
      await openAppSettings();
    } else {
      final result = await item.permission.request();
      if (!result.isGranted && !result.isLimited) {
        await openAppSettings();
      }
    }
    _load();
  }

  ({String label, Color color}) _display(PermissionStatus status) {
    if (status.isGranted) return (label: 'Granted', color: Colors.green);
    if (status.isLimited) {
      return (label: 'Limited', color: const Color(0xFFB8860B));
    }
    return (label: 'Denied', color: Colors.red);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions List')),
      body: FutureBuilder<List<PermissionItem>>(
        future: _permissions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No permissions available.'));
          }

          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final display = _display(item.status);
              return ListTile(
                title: Text(
                  item.name,
                  style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                    color: onSurface,
                  ),
                ),
                subtitle: Text(
                  display.label,
                  style: TextStyle(color: display.color),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.settings, color: onSurface),
                  onPressed: () => _onTap(item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
