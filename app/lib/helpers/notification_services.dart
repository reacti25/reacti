import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/notification_route.dart';
import 'package:reacti_app/networks/api_access.dart';
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

/// Persists a refreshed FCM [token] and re-registers it with the backend.
///
/// FCM rotates a device's token periodically (and on reinstall/restore). Without
/// this, the app only ever posted the token it had at login, so after a rotation
/// the backend kept pushing to a dead token and notifications silently stopped
/// until the next re-login. Called from the [FirebaseMessaging.onTokenRefresh]
/// stream so a rotation re-registers immediately.
///
/// No-op registration when logged out or when no device id is stored — there is
/// nothing to register the token against, and hitting the authed endpoint while
/// logged out would just 401. The token is always cached locally regardless.
Future<void> saveAndRegisterFcmToken(String token) async {
  appData.write(kKeyFCMToken, token);
  final deviceId = appData.read(kKeyDeviceID);
  final loggedIn = appData.read(kKeyIsLoggedIn) == true;
  if (deviceId != null && loggedIn) {
    await addTokenRx.addToken(deviceId: deviceId, token: token);
  }
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

  /// Opens the conversation a tapped notification points at.
  ///
  /// Called for taps from foreground, background, and terminated (cold-start)
  /// states. Decodes the FCM `data` payload via [decodeNotificationRoute] and
  /// navigates to the matching chat; a `null` [message] (no notification
  /// launched the app) or an unrecognised payload just opens the app normally.
  void handleMessage(RemoteMessage? message) {
    if (message == null) return;
    log("Clicked: ${message.data}");
    final target = decodeNotificationRoute(
      Map<String, dynamic>.from(message.data),
    );
    if (target == null) return;
    NavigationService.navigateToWithArgs(target.route, target.args);
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
    // When the app is in the FOREGROUND, don't let the OS play the push sound:
    // the in-app "message received" tone (receive.wav, played from the chat's
    // realtime handler) is the single sound in that case. Otherwise a message
    // arriving while you're in the app made two sounds at once — the OS push
    // and the in-app tone. Background/terminated pushes are unaffected (these
    // options only apply in the foreground) and still play their alert sound.
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: false,
    );

    _firebaseMessaging.getInitialMessage().then(handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

    // Re-register the FCM token whenever it rotates, so push never silently
    // dies between logins (the token is otherwise only posted at login).
    _firebaseMessaging.onTokenRefresh.listen(saveAndRegisterFcmToken);

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
              // Foreground only (this handler runs when the app is open), so keep
              // it silent — the in-app receive tone is the single sound. The
              // background handler shows the OS notification with its sound.
              silent: true,
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
        // iOS must have an APNS token before an FCM token can be issued. On a
        // FRESH install that registration can take several seconds, so poll for
        // it (up to ~15s) instead of a single 1s wait that gives up too early —
        // the old behaviour left new installs with no APNS token, so they never
        // got an FCM token, never registered for push, and never received a
        // notification.
        String? apnsToken;
        for (var attempt = 0; attempt < 15; attempt++) {
          apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
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
