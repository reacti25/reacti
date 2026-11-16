import 'dart:async';

import 'package:reacti_app/features/chat/presentation/widget/picked_media_review_screen.dart';
import 'package:reacti_app/analytics/activation_funnel.dart';
import 'package:reacti_app/analytics/analytics_bootstrap.dart';
import 'package:reacti_app/analytics/analytics_route_observer.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/analytics/frame_jank_reporter.dart';
import 'package:reacti_app/analytics/session_tracker.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/app_lock/app_lock_gate.dart';
import 'package:reacti_app/firebase_options.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/feedback_service.dart';
import 'package:reacti_app/helpers/helpers_method.dart';
import 'package:reacti_app/helpers/feature_flags.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/network_status.dart';
import 'package:reacti_app/helpers/register_provider.dart';
import 'package:reacti_app/loading.dart';
import 'package:reacti_app/networks/auth_token_store.dart';
import 'package:reacti_app/features/invite/data/invite_deep_links.dart';
import 'package:reacti_app/networks/dio/dio.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:reacti_app/theme/theme_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';

import 'helpers/notification_services.dart';

/// Top-level handler invoked by Firebase Messaging when a push notification
/// arrives while the app is terminated or in the background.
///
/// Must be a top-level (or static) function so the background isolate can
/// reference it. Currently a no-op: the payload [message] is accepted but not
/// processed.
Future<void> backgroundHandler(RemoteMessage message) async {}

// MyHttpOverrides — an HttpOverrides subclass that accepted every TLS
// certificate, disabling validation app-wide — was removed (CRITICAL
// security item, backlog §1). It was defined but never activated, so
// removing it has no runtime effect; deleting it removes the loaded
// gun.

/// Shared navigation observer, created lazily after DI is ready and reused by
/// both [MyApp]'s `navigatorObservers` and the frame-jank reporter (which tags
/// its windows with the observer's current screen). One instance so the screen
/// context is consistent across `screen_view`/`screen_render`/`frame_jank`.
final AnalyticsRouteObserver analyticsRouteObserver = AnalyticsRouteObserver(
  locator<AnalyticsService>(),
);

/// Application entry point.
///
/// Bootstraps the app before the first frame: ensures the Flutter binding is
/// ready, initialises Firebase, [GetStorage] and analytics side by side (each
/// step timed for `app_open`), wires dependency injection
/// via [diSetUp], registers the background push handler and notification
/// service, creates the shared Dio client, configures the system status-bar
/// overlay style, and finally hands control to [MyApp] through [runApp].
void main() async {
  // Measured for the analytics `cold_start_ms`; started before any work so it
  // reflects time-to-first-frame. Inert unless analytics is enabled.
  final startupStopwatch = Stopwatch()..start();

  // Required before any async work that touches platform channels.
  WidgetsFlutterBinding.ensureInitialized();

  // Android gallery: the system Photo Picker (no media permission needed).
  enableAndroidPhotoPicker();

  // These steps do not depend on one another, so they run side by side: the
  // start then waits for the slowest, not the sum. Firebase, the GetStorage KV
  // store, hydrating the in-memory access-token cache from secure storage (so
  // the synchronous AuthTokenStore.instance.token reads, the Dio header and
  // chat init, see the persisted session before any screen builds), the app
  // version, and the analytics SDK. Everything that DOES depend on them
  // (diSetUp needs GetStorage and the version) runs after this completes.
  // Each one is timed, so `app_open` can say which step a slow start waited on.
  final timings = StartupTimings();
  await Future.wait([
    timings.time(
      Props.firebaseInitMs,
      () => Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    ),
    timings.time(Props.storageInitMs, GetStorage.init),
    timings.time(Props.tokenLoadMs, AuthTokenStore.instance.load),
    _captureAppInfo(),
    // Analytics: default-off (no-op unless a build supplies keys), fail-safe.
    // The test-lab answer comes first: a lab robot starts no analytics.
    timings.time(Props.analyticsInitMs, () async {
      await AnalyticsBootstrap.detectTestLab();
      await AnalyticsBootstrap.initPostHog();
    }),
  ]);

  diSetUp();

  // Seed chat send/receive haptics from the stored preference (default on).
  FeedbackService.setEnabled(appData.read(kKeySoundHapticsEnabled) != false);

  FirebaseMessaging.onBackgroundMessage(backgroundHandler);
  NotificationService().initNotification();

  // Stamp the X-Analytics-Opt-Out header on requests while opted out, so the
  // backend emits no event carrying this user's id. Read live per request.
  DioSingleton.isAnalyticsOptedOut =
      () => appData.read(kKeyAnalyticsOptOut) == true;
  DioSingleton.instance.create();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // or a dark color
      statusBarIconBrightness: Brightness.light, // White icons on Android
      statusBarBrightness: Brightness.dark, // White icons on iOS
    ),
  );

  // Starts the time-to-value clock. Awaited, and before anything can report a
  // milestone: a step measured against a clock that has not started would be
  // dropped from the funnel rather than merely mistimed.
  await ActivationFunnel.ensureStarted();

  // Pre-fetch remote feature flags into the synchronous cache. Fire-and-forget;
  // until it resolves, flags fall back to their --dart-define override or safe
  // default, so nothing is blocked and the safe path is unchanged.
  unawaited(FeatureFlags.instance.load());
  _identifyCurrentUser();
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => AnalyticsBootstrap.trackAppOpen(
      locator<AnalyticsService>(),
      startupStopwatch,
      steps: timings.props,
    ),
  );

  // Open the first analytics session and close it whenever the app is
  // backgrounded, which is the only source of session length.
  SessionTracker.start();

  // Report UI jank over frame windows, tagged with the current screen.
  // Observation only and no-op until analytics is enabled.
  FrameJankReporter(
    locator<AnalyticsService>(),
    currentScreen: () => analyticsRouteObserver.currentScreen,
  ).start();

  // Begin caching the network class for analytics segmentation (and later
  // Wi-Fi-only prefetch). Fire-and-forget; failure leaves it at `unknown`.
  unawaited(NetworkStatus.instance.start());

  // runApp, wrapped in Sentry when enabled (else a plain runApp — unchanged).
  // Sentry honours the analytics opt-out (drops events when opted out).
  final crashReporterClock = Stopwatch()..start();
  await AnalyticsBootstrap.runAppGuarded(() {
    timings.record(
      Props.crashReporterInitMs,
      crashReporterClock.elapsedMilliseconds,
    );
    runApp(const MyApp());
  }, isOptedOut: () => appData.read(kKeyAnalyticsOptOut) == true);

  // Listen for tapped invite Universal Links (reacti.io/i/{code}) → open the
  // connect screen. Fire-and-forget; failures never block the app.
  unawaited(InviteDeepLinks.init());
}

/// Captures the running app version and build for the analytics context.
///
/// Must finish BEFORE DI builds the analytics service, so every event carries
/// the release and perf metrics can be broken down by version. Guarded:
/// analytics must never block or break startup.
Future<void> _captureAppInfo() async {
  try {
    final info = await PackageInfo.fromPlatform();
    AnalyticsContext.captureAppInfo(
      version: info.version,
      build: info.buildNumber,
    );
  } catch (_) {
    // Leave version empty: an unknown release is omitted, never guessed.
  }
}

/// Associates analytics events with the already-logged-in user (by HASHED id).
///
/// Fire-and-forget and no-op when signed out or analytics is disabled — the raw
/// id never leaves the device (see [AnalyticsService.identify]).
void _identifyCurrentUser() {
  try {
    final userId = appData.read(kKeyUserId);
    if (userId != null) {
      locator<AnalyticsService>().identify(userId.toString());
    }
  } catch (_) {
    // Analytics must never break startup.
  }
}

/// Root widget of the application.
///
/// Wires up the [providers] used by `provider` for state management and hosts
/// a [PopScope] above [UtillScreenMobile].
class MyApp extends StatelessWidget {
  /// Creates the root [MyApp] widget.
  const MyApp({super.key});

  /// Builds the provider/layout shell.
  ///
  /// Side effects on each build: [rotation] locks the supported device
  /// orientations and [setInitValue] seeds persisted defaults. [PopScope] is
  /// configured with `canPop: false` so the OS back gesture cannot exit the
  /// app outright.
  @override
  Widget build(BuildContext context) {
    rotation();
    setInitValue();
    return MultiProvider(
      providers: providers,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) async {},
        child: const UtillScreenMobile(),
      ),
    );
  }
}

/// Configures screen-size adaptation and the [GetMaterialApp] instance.
///
/// Exists to keep [ScreenUtilInit] (the `flutter_screenutil` design-size
/// adapter) separate from [MyApp]'s provider wiring. It owns the app theme,
/// routing ([RouteGenerator.generateRoute]), the global [NavigationService]
/// key, and the initial [Loading] route.
class UtillScreenMobile extends StatelessWidget {
  /// Creates the [UtillScreenMobile] widget.
  const UtillScreenMobile({super.key});

  /// Builds the [GetMaterialApp] inside a [ScreenUtilInit] using a
  /// `375x812` reference design size for responsive scaling.
  @override
  Widget build(BuildContext context) {
    // Watched so a theme change rebuilds GetMaterialApp and applies app-wide.
    final themeMode = context.watch<ThemeController>().themeMode;
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Reacti',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          builder: (context, widget) {
            // Status-bar icons per mode (dark icons on the light canvas, light
            // icons on dark) for screens without an AppBar to set it — the
            // custom chat-list header among them.
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value:
                  Theme.of(context).brightness == Brightness.dark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark,
              // Inside GetMaterialApp's builder so the cover sits above every
              // route including dialogs, and above the Navigator rather than
              // inside it — a lock a back gesture could dismiss is decoration.
              child: AppLockGate(
                child: MediaQuery(data: MediaQuery.of(context), child: widget!),
              ),
            );
          },
          navigatorKey: NavigationService.navigatorKey,
          // Observation only — emits screen_view/screen_render per navigation,
          // never alters it. Shared instance (see [analyticsRouteObserver]).
          navigatorObservers: [analyticsRouteObserver],
          onGenerateRoute: RouteGenerator.generateRoute,
          home: const Loading(),
        );
      },
    );
  }
}
