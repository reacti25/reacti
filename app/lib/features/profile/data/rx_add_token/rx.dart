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

/// Reactive data source for push-token registration.
///
/// Bridges [AddTokenApi] with an RxDart [BehaviorSubject] so the UI can react
/// to the registration outcome, while layering in session handling (logout on
/// HTTP 401) on top of the base [RxResponseInt] contract.
final class AddTokenRx extends RxResponseInt<Map> {
  /// Creates the data source with the [empty] seed value and the
  /// [dataFetcher] stream controller supplied by the DI layer.
  AddTokenRx({required super.empty, required super.dataFetcher});

  /// Broadcast stream of the latest token-registration response.
  ValueStream get getFileData => dataFetcher.stream;

  /// The underlying HTTP client used to perform the network call.
  final api = AddTokenApi.instance;

  /// Registers the device's FCM [token] for [deviceId] with the backend.
  ///
  /// Returns `true` once the response has been pushed to subscribers, or
  /// `false` if the request failed (the error is also added to the stream
  /// via [handleErrorWithReturn]).
  Future<bool> addToken({
    required String deviceId,
    required String token,
  }) async {
    try {
      final data = await api.addToken(deviceId: deviceId, token: token);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed registration by emitting the [error] to subscribers.
  ///
  /// On an HTTP 401 the session is treated as expired: local data is wiped,
  /// the logged-in flag is cleared and the user is routed back to login.
  /// Other [DioException]s are simply logged. Always returns `false` so
  /// callers can treat the outcome as a boolean success flag.
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

  /// Publishes the successful registration [data] to subscribers.
  ///
  /// Also re-asserts the logged-in flag, then returns the same [data].
  @override
  dynamic handleSuccessWithReturn(dynamic data) {
    appData.write(kKeyIsLoggedIn, true);
    dataFetcher.sink.add(data);
    return data;
  }
}
