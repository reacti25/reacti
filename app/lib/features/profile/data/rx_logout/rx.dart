import 'dart:developer';

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/networks/stream_cleaner.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/streams.dart';

import '../../../../helpers/di.dart';
import '../../../../networks/rx_base.dart';
import 'api.dart';

/// Reactive data source for user logout.
///
/// Bridges [LogoutApi] with an RxDart [BehaviorSubject] and layers in session
/// handling (logout on HTTP 401) over the base [RxResponseInt].
final class LogoutRx extends RxResponseInt<Map> {
  /// Creates the data source with the [empty] seed value and the
  /// [dataFetcher] stream controller supplied by the DI layer.
  LogoutRx({required super.empty, required super.dataFetcher});

  /// Broadcast stream of the latest logout response.
  ValueStream get collectionStream => dataFetcher.stream;

  /// The underlying HTTP client used to perform the network call.
  final api = LogoutApi.instance;

  /// Logs the current user out and publishes the response to subscribers.
  ///
  /// Returns `true` on success, or `false` if the request failed.
  Future<bool> userLogout() async {
    try {
      final data = await api.userLogout();
      handleSuccessWithReturn(data);
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

  /// Publishes the successful logout [data] to subscribers and returns it.
  @override
  dynamic handleSuccessWithReturn(dynamic data) {
    appData.write(kKeyIsLoggedIn, true);
    dataFetcher.sink.add(data);
    return data;
  }
}
