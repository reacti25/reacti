import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/toast.dart';
import '../../../../networks/dio/dio.dart';
import '../../model/login_response.dart';
import 'api.dart';

/// Reactive wrapper around [LoginApi] that streams the login result and
/// persists the resulting session.
///
/// Extends [RxResponseInt] with a [LoginResponse] payload: a successful login
/// also writes the auth token, login flag and user id to local storage.
final class LoginRx extends RxResponseInt<LoginResponse> {
  /// The underlying HTTP data source used to perform the login request.
  final api = LoginApi.instance;

  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to
  /// [RxResponseInt].
  LoginRx({required super.empty, required super.dataFetcher});

  /// The broadcast stream emitting the latest [LoginResponse] or error.
  ValueStream get getFileData => dataFetcher.stream;

  /// Logs the user in with [email] and [password] and reports success.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn], which shows a toast and returns `false`.
  Future<bool> login({required String email, required String password}) async {
    try {
      final data = await api.login(email: email, password: password);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Persists the authenticated session and emits [data] to listeners.
  ///
  /// Writes the access token, logged-in flag and user id into local storage,
  /// updates the shared [DioSingleton] so future requests are authenticated,
  /// then pushes [data] onto [dataFetcher]. Returns the same [data].
  @override
  handleSuccessWithReturn(LoginResponse data) {
    var userId = data.data!.id;
    log("User ID IS ==========> $userId");
    appData.write(kKeyAccessToken, data.data?.token);
    appData.write(kKeyIsLoggedIn, true);
    appData.write(kKeyUserId, userId);

    // String token = appData.read(kKeyAccessToken);
    DioSingleton.instance.update(data.data!.token!);

    dataFetcher.sink.add(data);
    return data;
  }

  /// Handles a failed login by surfacing the backend error message.
  ///
  /// For any [DioException] the backend `message` is shown via [ToastUtil].
  /// The [error] is always pushed onto [dataFetcher]; always returns `false`.
  @override
  handleErrorWithReturn(error) {
    if (error is DioException) {
      if (error.response?.statusCode == 400) {
        ToastUtil.showErrorMessage(error.response?.data['message']);
      } else if (error.response!.data['code'] == 403) {
        ToastUtil.showErrorMessage(error.response?.data['message']);
      } else {
        ToastUtil.showErrorMessage(error.response?.data['message']);
      }
    }
    // log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
