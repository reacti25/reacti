import 'dart:developer';

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/stream_cleaner.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/streams.dart';

import '../../../../helpers/di.dart';
import '../../../../networks/rx_base.dart';
import 'api.dart';

/// Reactive data source for user logout.
///
/// Bridges [LogoutApi] with an RxDart [BehaviorSubject] and layers in session
/// handling (logout on HTTP 401) over the base [RxResponseInt].
class LogoutRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to perform the logout request.
  ///
  /// Injectable: in production it defaults to the shared [LogoutApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final LogoutApi api;

  /// Creates the data source with the [empty] seed value and the
  /// [dataFetcher] stream controller supplied by the DI layer.
  ///
  /// [api] defaults to the shared [LogoutApi] singleton when omitted — so
  /// the production call sites are unaffected — and tests may inject a fake.
  LogoutRx({LogoutApi? api, required super.empty, required super.dataFetcher})
    : api = api ?? LogoutApi.instance;

  /// Broadcast stream of the latest logout response.
  ValueStream get collectionStream => dataFetcher.stream;

  /// Logs the current user out and publishes the response to subscribers.
  ///
  /// Returns `true` on success, or `false` if the request failed.
  Future<bool> userLogout() async {
    try {
      final data = await api.userLogout();
      await handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed logout by emitting the [error] to subscribers.
  ///
  /// On an HTTP 401 the session is treated as expired: local data is wiped,
  /// the logged-in flag is cleared and the user is routed back to login.
  /// Other [DioException]s are simply logged. Always returns `false`.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      // An expired/invalid token means the session is dead; force re-login.
      if (error.response!.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        log(error.response!.data["message"]);
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }

  /// Clears the session on a successful logout, then publishes [data].
  ///
  /// A successful logout must leave the app with no usable credentials:
  /// [totalDataClean] erases the access token / user id / FCM token, drops
  /// the logged-in flag, and rebuilds the Dio client unauthenticated.
  /// Previously this handler instead wrote `kKeyIsLoggedIn = true` and left
  /// the token in storage with the `Bearer` header still attached, so the
  /// "logged-out" user kept working credentials until the app restarted.
  /// Navigation back to login is handled by the caller.
  @override
  Future<dynamic> handleSuccessWithReturn(dynamic data) async {
    await totalDataClean();
    dataFetcher.sink.add(data);
    return data;
  }
}
