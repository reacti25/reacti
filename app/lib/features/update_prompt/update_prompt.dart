import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../networks/dio/dio.dart';
import '../../networks/endpoints.dart';

/// The newest version available on this phone's platform and where to get
/// it, as the server says (`GET /api/app-version`); null when there is none.
typedef LatestVersionLookup =
    Future<({String version, String url})?> Function();

/// Offers to update when this app is older than the newest version live in
/// its store: a small dialog with "Update" (opens the store) and "Not now".
///
/// Asked once per app run, on the home screen, so "Not now" holds until the
/// next time Reacti is opened. The server decides what "newest" is (the admin
/// types it in once a release is live), so nobody is sent to a store page
/// that does not have the update yet. Any failure (no network, an old server)
/// just shows nothing.
class UpdatePrompt {
  UpdatePrompt._();

  static bool _askedThisRun = false;

  /// Where the newest version comes from; replaceable in tests.
  static LatestVersionLookup lookup = _askServer;

  /// This app's own version, like `1.8.3`; replaceable in tests.
  static Future<String> Function() currentVersion =
      () async => (await PackageInfo.fromPlatform()).version;

  /// Opens the store; replaceable in tests.
  static Future<bool> Function(Uri) openStore =
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Lets a test ask again in the same run.
  @visibleForTesting
  static void debugReset() => _askedThisRun = false;

  /// Shows the dialog over [context] when an update is out, once per run.
  static Future<void> showIfOutdated(BuildContext context) async {
    if (_askedThisRun) return;
    _askedThisRun = true;
    try {
      final latest = await lookup();
      if (latest == null) return;
      if (!isNewer(latest.version, await currentVersion())) return;
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialog) => AlertDialog(
              key: const Key('update-prompt'),
              title: const Text('A new version of Reacti is out'),
              content: const Text(
                'Update now to get the newest features and fixes.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialog).pop(),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialog).pop();
                    openStore(Uri.parse(latest.url));
                  },
                  child: const Text('Update'),
                ),
              ],
            ),
      );
    } catch (_) {
      // Never in the way: no prompt is the safe failure.
    }
  }

  /// Whether version [latest] is newer than [current], compared number by
  /// number (`1.10.0` is newer than `1.9.9`); a missing part counts as 0.
  /// Anything that is not a version is never newer.
  static bool isNewer(String latest, String current) {
    List<int>? parts(String v) {
      final list = v.trim().split('.').map(int.tryParse).toList();
      return list.contains(null) || list.isEmpty ? null : list.cast<int>();
    }

    final a = parts(latest);
    final b = parts(current);
    if (a == null || b == null) return false;
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// The server's answer for this platform.
  static Future<({String version, String url})?> _askServer() async {
    final response = await getHttp(EndPoints.appVersion());
    final platform = response.data['data'][Platform.isIOS ? 'ios' : 'android'];
    final version = platform?['latest_version'];
    final url = platform?['update_url'];
    if (version is! String || url is! String) return null;
    return (version: version, url: url);
  }
}
