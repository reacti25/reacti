import 'dart:developer';
import 'dart:io';

import 'package:achiar_expert_app/features/onboard/presentation/on_board_screen.dart';
import 'package:achiar_expert_app/helpers/helpers_method.dart';
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

class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
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

  Future<bool> requestCameraAndMicPermission() async {
    if (Platform.isIOS) {
      // For iOS, use camera package for better UX
      return await _requestPermissionsIOS();
    } else {
      // For Android, use permission_handler
      return await _requestPermissionsAndroid();
    }
  }

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

  Future<bool> _requestPermissionsAndroid() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    return cameraStatus.isGranted && micStatus.isGranted;
  }

  bool _isLoading = true;

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
