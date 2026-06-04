import 'dart:developer';
import 'dart:io';

import 'package:reacti_app/features/onboard/presentation/on_board_screen.dart';
import 'package:reacti_app/helpers/helpers_method.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'constants/app_constants.dart';
import 'features/auth/presentation/login/login_screen.dart';
import 'features/navigation/presentation/navigation_screen.dart';
import 'helpers/di.dart';
import 'helpers/permission_helper.dart';
import 'networks/dio/dio.dart';
import 'splash_screen.dart';

/// Startup gate widget that decides which screen to show first.
///
/// While initial data loads it renders [SplashScreen], then routes to
/// [OnBoardScreen], [NavigationScreen], or [LoginScreen] depending on the
/// persisted first-run and logged-in flags. It also requests camera and
/// microphone permissions early so later media flows do not stall.
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
  /// Loads persisted session data, requests generic permissions via
  /// [PermissionHelper], and explicitly prompts for camera/microphone access.
  @override
  void initState() {
    super.initState();
    loadInitialData();
    PermissionHelper().getPermissions();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   // Delay permission request slightly for better UX
    //   Future.delayed(Duration(milliseconds: 500), () {
    //     // _loadDataAndPermissions();
    //     requestCameraAndMicPermission();
    //   });
    // });
    requestCameraAndMicPermission();
  }

  /// Requests camera and microphone permission using a platform-specific path.
  ///
  /// Delegates to [_requestPermissionsIOS] on iOS and
  /// [_requestPermissionsAndroid] elsewhere. Returns `true` only when both
  /// permissions end up granted.
  Future<bool> requestCameraAndMicPermission() async {
    if (Platform.isIOS) {
      // For iOS, use camera package for better UX
      return await _requestPermissionsIOS();
    } else {
      // For Android, use permission_handler
      return await _requestPermissionsAndroid();
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

  /// Requests the Android camera/microphone runtime permissions directly.
  ///
  /// Returns `true` only when both [Permission.camera] and
  /// [Permission.microphone] are granted.
  Future<bool> _requestPermissionsAndroid() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    return cameraStatus.isGranted && micStatus.isGranted;
  }

  /// Whether startup data is still loading; controls the splash-vs-route swap.
  bool _isLoading = true;

  /// Loads persisted session state and prepares the HTTP client.
  ///
  /// Seeds defaults via [setInitValue], and when a logged-in session exists
  /// it reads the stored access token and refreshes [DioSingleton] so
  /// subsequent requests are authenticated. Clears [_isLoading] when done.
  Future<void> loadInitialData() async {
    await setInitValue();
    bool data = appData.read(kKeyIsLoggedIn) ?? false;
    if (data) {
      String token = appData.read(kKeyAccessToken);
      log("Token is ===========> $token");
      log("FCM Token is ===========> ${appData.read(kKeyFCMToken)}");
      DioSingleton.instance.update(token);
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Renders [SplashScreen] while loading, then the resolved start screen:
  /// [OnBoardScreen] on first run, [NavigationScreen] when logged in,
  /// otherwise [LoginScreen].
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    } else {
      return appData.read(kKeyIsFirstTime)
          ? OnBoardScreen()
          : appData.read(kKeyIsLoggedIn)
          ? const NavigationScreen()
          : const LoginScreen();
    }
  }
}
