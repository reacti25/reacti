import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/helpers/di.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  log("Background Message: ${message.notification?.title}");
}

class NotificationService {
  // 1. THIS PREVENTS DUPLICATE INSTANCES
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotification = FlutterLocalNotificationsPlugin();

  // 2. THIS PREVENTS DUPLICATE LISTENERS
  bool _isInitialized = false;

  final _androidChannel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
  );

  void handleMessage(RemoteMessage? message) {
    if (message == null) return;
    log("Clicked: ${message.data}");
  }

  Future<void> initLocalNotification() async {
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android, iOS: ios);

    await _localNotification.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (payload) {
        if (payload.payload != null) {
          final data = jsonDecode(payload.payload!);
          handleMessage(RemoteMessage(data: Map<String, dynamic>.from(data)));
        }
      },
    );

    if (Platform.isAndroid) {
      final platform =
          _localNotification
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await platform?.createNotificationChannel(_androidChannel);
    }
  }

  Future<void> initPushNotification() async {
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _firebaseMessaging.getInitialMessage().then(handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      // 3. THIS PREVENTS DUPLICATES ON iOS
      // Only show local notification on Android. iOS shows its own.
      if (Platform.isAndroid) {
        _localNotification.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  Future<void> initNotification() async {
    // 4. STOP IF ALREADY RUNNING
    if (_isInitialized) return;

    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      String? fcmToken;
      if (Platform.isIOS) {
        await Future.delayed(const Duration(seconds: 1));
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null) fcmToken = await _firebaseMessaging.getToken();
      } else {
        fcmToken = await _firebaseMessaging.getToken();
      }

      if (fcmToken != null) appData.write(kKeyFCMToken, fcmToken);

      await initPushNotification();
      await initLocalNotification();

      _isInitialized = true; // Mark as done
    } catch (e) {
      log("Error: $e");
    }
  }
}
