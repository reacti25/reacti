// Pins which permissions the Settings → Permissions screen lists (plan Step 7).
// Android has no photo permission any more (the system Photo Picker needs
// none), so it must not show a Photos row that can never be granted.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/helpers/permission_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Every status query answers "granted"; only the list's shape matters.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async => 1,
        );
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<List<String>> namesOn(TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    final items = await PermissionHelper().getPermissions();
    return [for (final i in items) i.name];
  }

  test('iOS lists photos', () async {
    expect(await namesOn(TargetPlatform.iOS), [
      'Camera',
      'Contacts',
      'Microphone',
      'Photos',
    ]);
  });

  test('Android lists no photos row', () async {
    expect(await namesOn(TargetPlatform.android), [
      'Camera',
      'Contacts',
      'Microphone',
    ]);
  });
}
