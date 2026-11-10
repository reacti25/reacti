import 'dart:developer';

import 'package:reacti_app/features/onboard/presentation/welcome_screen.dart';
import 'package:reacti_app/helpers/helpers_method.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'constants/app_constants.dart';
import 'features/auth/presentation/login/login_screen.dart';
import 'features/navigation/presentation/navigation_screen.dart';
import 'helpers/cam_mic_primer.dart';
import 'helpers/di.dart';
import 'helpers/permission_helper.dart';
import 'networks/auth_token_store.dart';
import 'networks/dio/dio.dart';
import 'splash_screen.dart';

/// Startup gate widget that decides which screen to show first.
///
/// While initial data loads it renders [SplashScreen], then routes to
/// [WelcomeScreen], [NavigationScreen], or [LoginScreen] depending on the
/// persisted first-run and logged-in flags. On iOS it also requests camera and
/// microphone permissions early; Android asks just in time instead (see
/// [CamMicPrimer.asksAtLaunch]).
class Loading extends StatefulWidget {
  /// Creates the [Loading] widget.
  const Loading({super.key});

  /// Creates the mutable state for this widget.
  @override
  State<Loading> createState() => _LoadingState();
}

/// [State] for [Loading]; owns the loading flag and startup side effects.
class _LoadingState extends State<Loading> {
  /// Kicks off startup work once the widget is inserted into the tree.
  ///
  /// Loads persisted session data, reads permission statuses via
  /// [PermissionHelper], and on iOS prompts for camera/microphone access.
  @override
  void initState() {
    super.initState();
    loadInitialData();
    PermissionHelper().getPermissions();
    if (CamMicPrimer.asksAtLaunch(defaultTargetPlatform)) {
      _requestPermissionsIOS();
    }
  }

  /// Triggers the iOS camera/microphone permission dialogs.
  ///
  /// iOS only surfaces the native prompt when a [CameraController] is actually
  /// initialised, so this briefly creates and disposes one to force the
  /// dialog, then re-checks [Permission.camera] and [Permission.microphone].
  /// Returns `false` if no cameras are available or an error is caught.
  Future<bool> _requestPermissionsIOS() async {
    try {
      // Get cameras first
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      // Initialize and immediately dispose - this triggers permission dialog
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: true,
      );

      // This triggers the native permission dialog
      await controller.initialize();
      await controller.dispose();

      // Check if permissions were granted
      await Future.delayed(Duration(milliseconds: 500));

      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;

      return cameraStatus.isGranted && micStatus.isGranted;
    } catch (e) {
      log("iOS permission error: $e");
      return false;
    }
  }

  /// The screen to show once loading ends; null while it still loads.
  ///
  /// Decided once, not read from storage on every build: the stored login
  /// flag turns true the moment someone signs in, so a rebuild during the
  /// hand-off to the home screen built a second home screen here, under the
  /// real one, and a newcomer got the first-run demo twice (found by the
  /// testing lab on the iPhone).
  StartScreen? _start;

  /// Loads persisted session state and prepares the HTTP client.
  ///
  /// Seeds defaults via [setInitValue], and when a logged-in session exists
  /// it reads the stored access token and refreshes [DioSingleton] so
  /// subsequent requests are authenticated. Then decides [_start].
  Future<void> loadInitialData() async {
    await setInitValue();
    final bool loggedIn = appData.read(kKeyIsLoggedIn) ?? false;
    if (loggedIn) {
      // The token is restored from the secure store (hydrated at startup in
      // main()); not logged — it is the bearer credential.
      final String token = AuthTokenStore.instance.token ?? '';
      DioSingleton.instance.update(token);
    }

    setState(() {
      _start = startScreenFor(
        firstTime: appData.read(kKeyIsFirstTime) ?? true,
        loggedIn: loggedIn,
      );
    });
  }

  /// Renders [SplashScreen] while loading, then the start screen [_start].
  @override
  Widget build(BuildContext context) => switch (_start) {
    null => const SplashScreen(),
    StartScreen.welcome => WelcomeScreen(),
    StartScreen.home => const NavigationScreen(),
    StartScreen.login => const LoginScreen(),
  };
}

/// The screens the app can open on.
enum StartScreen { welcome, home, login }

/// Which screen the app opens on: the welcome carousel on the very first
/// run, the home screen with a saved session, otherwise login.
StartScreen startScreenFor({required bool firstTime, required bool loggedIn}) =>
    firstTime
        ? StartScreen.welcome
        : loggedIn
        ? StartScreen.home
        : StartScreen.login;
