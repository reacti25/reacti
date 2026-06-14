import 'package:get_it/get_it.dart';
import 'package:get_storage/get_storage.dart';

import '../analytics/analytics_bootstrap.dart';
import '../analytics/analytics_service.dart';

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
  // Analytics seam: PostHog-backed when enabled (keys present), else a no-op.
  // Default-off, so a plain/production build registers the no-op and behaves
  // identically. Guarded so a test that pre-registers a fake is not clobbered.
  if (!locator.isRegistered<AnalyticsService>()) {
    locator.registerSingleton<AnalyticsService>(
      AnalyticsBootstrap.buildService(),
    );
  }
}
