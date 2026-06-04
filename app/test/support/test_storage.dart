// Shared test fixture for GetStorage-backed code.
//
// Many rx_* success handlers persist session data through `appData`
// (`locator.get<GetStorage>()` — see lib/helpers/di.dart). A unit test
// that exercises those paths must initialise GetStorage and register it
// in the locator first. GetStorage resolves its directory via
// path_provider, which has no platform implementation under
// `flutter test`, so the channel is stubbed to a temp directory.

import 'dart:io';

import 'package:reacti_app/helpers/di.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

/// Initialises GetStorage for a unit test and registers it in [locator].
///
/// Safe to call from multiple tests in one run: the locator registration
/// is guarded so it only happens once. Call this in `setUp()` (or at the
/// start of a test) before exercising any code that touches `appData`.
Future<void> initTestGetStorage() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub path_provider so GetStorage.init() can resolve a directory.
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        channel,
        (MethodCall call) async => Directory.systemTemp.path,
      );

  await GetStorage.init();

  if (!locator.isRegistered<GetStorage>()) {
    locator.registerSingleton<GetStorage>(GetStorage());
  }
}
