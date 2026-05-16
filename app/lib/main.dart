import 'dart:io';

import 'package:achiar_expert_app/constants/custome_theme.dart';
import 'package:achiar_expert_app/firebase_options.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/di.dart';
import 'package:achiar_expert_app/helpers/helpers_method.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/register_provider.dart';
import 'package:achiar_expert_app/loading.dart';
import 'package:achiar_expert_app/networks/dio/dio.dart';
import 'package:auto_animated/auto_animated.dart';
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

/// [HttpOverrides] implementation that accepts every TLS certificate.
///
/// WARNING: this weakens transport security by making
/// [HttpClient.badCertificateCallback] return `true` for any certificate,
/// host, and port — effectively disabling certificate validation. It is
/// flagged for cleanup (see the repo `CLAUDE.md`); do not extend it and do not
/// ship it as the long-term behaviour.
class MyHttpOverrides extends HttpOverrides {
  /// Creates an [HttpClient] whose certificate check is bypassed.
  ///
  /// Delegates to [super.createHttpClient] and then overrides
  /// [HttpClient.badCertificateCallback] so that any presented certificate
  /// [cert] for the given [host] and [port] is treated as valid.
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

/// Application entry point.
///
/// Bootstraps the app before the first frame: ensures the Flutter binding is
/// ready, initialises Firebase and [GetStorage], wires dependency injection
/// via [diSetUp], registers the background push handler and notification
/// service, creates the shared Dio client, configures the system status-bar
/// overlay style, and finally hands control to [MyApp] through [runApp].
void main() async {
  // Required before any async work that touches platform channels.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GetStorage.init();
  diSetUp();

  FirebaseMessaging.onBackgroundMessage(backgroundHandler);
  NotificationService().initNotification();

  DioSingleton.instance.create();
  // try {
  //   if (Platform.isIOS) {
  //     // Check if running on a simulator
  //     if (Platform.environment.containsKey('SIMULATOR_DEVICE_NAME')) {
  //       log('Running on an iOS simulator. Skipping high refresh rate setting.');
  //       return;
  //     }
  //   }

  //   // Set high refresh rate for supported devices
  //   await FlutterDisplayMode.setHighRefreshRate();
  //   log('High refresh rate mode set successfully.');
  // } catch (e) {
  //   log('Error setting high refresh rate: $e');
  // }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // or a dark color
      statusBarIconBrightness: Brightness.light, // White icons on Android
      statusBarBrightness: Brightness.dark, // White icons on iOS
    ),
  );

  runApp(const MyApp());
}

/// Root widget of the application.
///
/// Wires up the [providers] used by `provider` for state management and hosts
/// the responsive layout scaffolding ([AnimateIfVisibleWrapper], [PopScope],
/// [LayoutBuilder]) above [UtillScreenMobile].
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
      child: AnimateIfVisibleWrapper(
        showItemInterval: const Duration(milliseconds: 150),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            // showMaterialDialog(context);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return const UtillScreenMobile();
            },
          ),
        ),
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
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Reacti',
          theme: ThemeData(
            primarySwatch: CustomTheme.kToDark,
            primaryColor: AppColors.allPrimaryColor,
            useMaterial3: false,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.c000000,
              elevation: 0,
              foregroundColor: AppColors.cFFFFFF,
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: AppColors.allPrimaryColor,
            ),
            scaffoldBackgroundColor: AppColors.scaffoldColor,
          ),

          builder: (context, widget) {
            return MediaQuery(data: MediaQuery.of(context), child: widget!);
          },
          navigatorKey: NavigationService.navigatorKey,
          onGenerateRoute: RouteGenerator.generateRoute,
          home: const Loading(),
        );
      },
    );
  }
}
