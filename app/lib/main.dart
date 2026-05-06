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

Future<void> backgroundHandler(RemoteMessage message) async {}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

class UtillScreenMobile extends StatelessWidget {
  const UtillScreenMobile({super.key});

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
