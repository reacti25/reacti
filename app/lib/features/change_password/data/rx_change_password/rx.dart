import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/streams.dart';

import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../helpers/toast.dart';
import '../../../../networks/rx_base.dart';
import '../../../../networks/stream_cleaner.dart';
import 'api.dart';

/// Reactive data source for password changes.
///
/// Bridges [ChnagePasswordApi] with an RxDart [BehaviorSubject] and layers in
/// session handling (logout on HTTP 401) over the base [RxResponseInt].
final class ChangePasswordRx extends RxResponseInt<Map> {
  /// Creates the data source with the [empty] seed value and the
  /// [dataFetcher] stream controller supplied by the DI layer.
  ChangePasswordRx({required super.empty, required super.dataFetcher});

  /// Broadcast stream of the latest password-change response.
  ValueStream get getFileData => dataFetcher.stream;

  /// The underlying HTTP client used to perform the network call.
  final api = ChnagePasswordApi.instance;

  /// Changes the user's password and publishes the response to subscribers.
  ///
  /// [oldPass], [newPass] and [confNewPass] are forwarded to the API.
  /// Returns `true` on success, or `false` if the request failed.
  Future<bool> changePassword({
    required String oldPass,
    required String newPass,
    required String confNewPass,
  }) async {
    try {
      final data = await api.changePassword(
        oldPass: oldPass,
        newPass: newPass,
        confNewPass: confNewPass,
      );
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed password change by emitting the [error] to subscribers.
  ///
  /// On an HTTP 401 the session is treated as expired: local data is wiped,
  /// the logged-in flag is cleared and the user is routed back to login.
  /// Other [DioException]s surface the backend message as an error toast.
  /// Always returns `false`.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      // An expired/invalid token means the session is dead; force re-login.
      if (error.response!.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        ToastUtil.showErrorMessage(error.response!.data["message"]);
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
