import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/networks/auth_token_store.dart';
import 'package:reacti_app/networks/dio/dio.dart';

/// Clears persisted session state so the app reverts to a logged-out
/// state.
///
/// Erases the access token, user id, and FCM token from [appData] (each
/// is read directly by HTTP / chat / push code, so leaving any of them
/// in storage means the "logged-out" user still has working
/// credentials), drops the [kKeyIsLoggedIn] flag, and rebuilds
/// [DioSingleton] as the unauthenticated client — without this the
/// in-memory `Bearer` header stays attached until the app restarts and
/// continues to authorise requests after logout.
///
/// Invoked on logout and on a 401 from the api (session expiry).
Future<void> totalDataClean() async {
  // The access token lives in the secure store; the rest are GetStorage keys.
  await AuthTokenStore.instance.clear();
  await appData.remove(kKeyUserId);
  await appData.remove(kKeyFCMToken);
  await appData.write(kKeyIsLoggedIn, false);

  // Drop the Bearer header from the shared HTTP client. The next login
  // calls update() with the new token.
  DioSingleton.instance.create();
}
