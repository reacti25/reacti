// Shared test fixture for GetStorage-backed code.
//
// Many rx_* success handlers persist session data through `appData`
// (`locator.get<GetStorage>()` — see lib/helpers/di.dart). A unit test
// that exercises those paths must initialise GetStorage and register it
// in the locator first. GetStorage resolves its directory via
// path_provider, which has no platform implementation under
// `flutter test`, so the channel is stubbed to a temp directory.

import 'dart:io';

import 'package:reacti_app/features/consent/data/consent_service.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/networks/auth_token_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

/// Per-process GetStorage container name.
///
/// `flutter test` runs test files concurrently, each in its own process. The
/// default GetStorage container all share one `GetStorage.gs` file in the temp
/// dir, so concurrent files racing to read/write it hit an OS file-lock error.
/// Keying the container on the process id gives each test file its own backing
/// file, eliminating the race. (Within a file the pid is constant, so the
/// usual single-container behaviour is preserved.)
final String _testContainer = 'test_$pid';

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

  await GetStorage.init(_testContainer);

  if (!locator.isRegistered<GetStorage>()) {
    locator.registerSingleton<GetStorage>(GetStorage(_testContainer));
  }

  // Mirror production DI: register the DG1 ConsentService (backed by the test
  // container) so code paths that resolve it via the locator — e.g. the login
  // success handler's consent sync — work under `flutter test`.
  if (!locator.isRegistered<ConsentService>()) {
    locator.registerLazySingleton<ConsentService>(
      () => ConsentService(storage: GetStorage(_testContainer)),
    );
  }
}

/// In-memory backing store for the mocked secure-storage channel.
final Map<String, String> _fakeSecureStore = {};

/// Installs an in-memory mock for the `flutter_secure_storage` platform
/// channel and resets [AuthTokenStore.instance] to a fresh, empty store.
///
/// The real plugin has no platform implementation under `flutter test`, so
/// code that persists the access token through [AuthTokenStore] would
/// otherwise throw a `MissingPluginException`. Call this in `setUp()` (or at
/// the start of a test) before exercising any code that touches the token.
void initTestSecureStorage() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _fakeSecureStore.clear();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        final args = (call.arguments as Map?) ?? const {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'write':
            _fakeSecureStore[key!] = args['value'] as String;
            return null;
          case 'read':
            return _fakeSecureStore[key];
          case 'delete':
            _fakeSecureStore.remove(key);
            return null;
          case 'deleteAll':
            _fakeSecureStore.clear();
            return null;
          case 'readAll':
            return Map<String, String>.from(_fakeSecureStore);
          case 'containsKey':
            return _fakeSecureStore.containsKey(key);
          default:
            return null;
        }
      });

  // Fresh store over the mocked channel, with an empty in-memory cache.
  AuthTokenStore.instance = AuthTokenStore();
}
