import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Firebase background message handler for FCM pushes received while the app
/// is terminated or backgrounded.
///
/// Annotated with `@pragma('vm:entry-point')` because it must survive tree
/// shaking — Firebase invokes it in a separate isolate. Currently it only
/// logs the incoming [message].
@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  log("Background Message: ${message.notification?.title}");
}

/// Singleton service that wires up Firebase Cloud Messaging and local
/// notifications for the app.
///
/// Centralises push-permission requests, FCM token retrieval, foreground
/// message handling, and Android notification-channel setup so the rest of
/// the app does not deal with these plugins directly.
class NotificationService {
  /// The single shared instance returned by the [NotificationService] factory.
  // 1. THIS PREVENTS DUPLICATE INSTANCES
  static final NotificationService _instance = NotificationService._internal();

  /// Returns the shared [NotificationService] singleton.
  factory NotificationService() => _instance;

  /// Private constructor enforcing the singleton pattern.
  NotificationService._internal();

  /// Firebase Cloud Messaging plugin handle.
  final _firebaseMessaging = FirebaseMessaging.instance;

  /// Local-notifications plugin used to surface FCM payloads on Android.
  final _localNotification = FlutterLocalNotificationsPlugin();

  /// Guards against re-running [initNotification] and registering duplicate
  /// message listeners.
  // 2. THIS PREVENTS DUPLICATE LISTENERS
  bool _isInitialized = false;

  /// Android notification channel used for high-importance push alerts.
  final _androidChannel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
  );

  /// Handles a notification tap by logging the [message] payload.
  ///
  /// Called for taps on both background and terminated-state notifications;
  /// a `null` [message] (no notification triggered the launch) is ignored.
  void handleMessage(RemoteMessage? message) {
    if (message == null) return;
    log("Clicked: ${message.data}");
  }

  /// Initialises the local-notifications plugin and Android channel.
  ///
  /// Configures iOS/Android init settings and a tap callback that decodes the
  /// JSON payload back into a [RemoteMessage] for [handleMessage]. The
  /// high-importance channel is created on Android only.
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

  /// Registers FCM message listeners for every app lifecycle state.
  ///
  /// Wires up initial-message, opened-app, background, and foreground
  /// handlers. For foreground messages a local notification is shown on
  /// Android only, since iOS already presents its own banner.
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

  /// Bootstraps the entire notification stack; safe to call repeatedly.
  ///
  /// Requests push permission, retrieves the FCM token (waiting for the APNS
  /// token first on iOS), persists it to [appData], and sets up push and
  /// local notification handling. The [_isInitialized] guard makes repeat
  /// calls no-ops; any failure is caught and logged rather than thrown.
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
        // iOS must have an APNS token before an FCM token can be issued.
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
