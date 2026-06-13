import 'package:get_it/get_it.dart';
import 'package:get_storage/get_storage.dart';

import '../features/consent/data/consent_service.dart';

/// The shared [GetIt] service-locator instance for dependency injection.
final locator = GetIt.instance;

/// The app-wide persistent key/value store, resolved from the [locator].
///
/// Used throughout the app for lightweight local persistence (auth flags,
/// device ID, FCM token, etc.). Resolving it here requires [diSetUp] to have
/// run first.
final appData = locator.get<GetStorage>();

/// Registers core singletons into the [locator].
///
/// Must be called once during app bootstrap (before [appData] is used) so the
/// [GetStorage] instance is available for the rest of the app's lifetime.
void diSetUp() {
  locator.registerSingleton<GetStorage>(GetStorage());
  // DG1 consent state (server-recorded, locally mirrored).
  locator.registerLazySingleton<ConsentService>(() => ConsentService());
}
