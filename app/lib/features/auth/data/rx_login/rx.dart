import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../analytics/analytics_buckets.dart';
import '../../../../analytics/analytics_locator.dart';
import '../../../../analytics/events.dart';
import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/toast.dart';
import '../../../../networks/auth_token_store.dart';
import '../../../../networks/dio/dio.dart';
import '../../model/login_response.dart';
import 'api.dart';

/// Reactive wrapper around [LoginApi] that streams the login result and
/// persists the resulting session.
///
/// Extends [RxResponseInt] with a [LoginResponse] payload: a successful login
/// also writes the auth token, login flag and user id to local storage.
class LoginRx extends RxResponseInt<LoginResponse> {
  /// The underlying HTTP data source used to perform the login request.
  ///
  /// Injectable: in production it defaults to the shared [LoginApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final LoginApi api;

  /// Creates the Rx wrapper.
  ///
  /// [api] defaults to the shared [LoginApi] singleton when omitted — so
  /// the production call sites in `api_access.dart` are unaffected — and
  /// tests may inject a fake. [empty] and [dataFetcher] are forwarded to
  /// [RxResponseInt].
  LoginRx({LoginApi? api, required super.empty, required super.dataFetcher})
    : api = api ?? LoginApi.instance;

  /// The broadcast stream emitting the latest [LoginResponse] or error.
  ValueStream get getFileData => dataFetcher.stream;

  /// Logs the user in with [email] and [password] and reports success.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn], which shows a toast and returns `false`.
  Future<bool> login({required String email, required String password}) async {
    try {
      final data = await api.login(email: email, password: password);
      await handleSuccessWithReturn(data);
      _trackLogin(success: true);
      return true;
    } catch (error) {
      // A returning user who cannot get back in is otherwise invisible: the
      // funnel only covers new accounts, and retention just shows them gone.
      _trackLogin(success: false, error: error);
      return handleErrorWithReturn(error);
    }
  }

  /// Emits `login_result`. Never carries the email or the message text, only
  /// the outcome and a coarse failure reason. Fire-and-forget.
  void _trackLogin({required bool success, Object? error}) {
    try {
      analytics.track(Events.loginResult, {
        Props.result: success ? 'success' : 'failure',
        if (!success) Props.failureReason: failureReasonFromError(error),
      });
    } catch (_) {
      // Measurement must never break a sign-in.
    }
  }

  /// Persists the authenticated session and emits [data] to listeners.
  ///
  /// Stores the access token in the secure store ([AuthTokenStore]), writes
  /// the logged-in flag and user id into GetStorage, updates the shared
  /// [DioSingleton] so future requests are authenticated, then pushes [data]
  /// onto [dataFetcher]. Returns the same [data].
  @override
  Future<LoginResponse> handleSuccessWithReturn(LoginResponse data) async {
    var userId = data.data!.id;
    log("User ID IS ==========> $userId");
    await AuthTokenStore.instance.save(data.data?.token);
    appData.write(kKeyIsLoggedIn, true);
    appData.write(kKeyUserId, userId);

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
