// ignore_for_file: use_build_context_synchronously

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../../helpers/toast.dart';
import '../../../../../../networks/rx_base.dart';
import 'api.dart';

/// Reactive wrapper around [ResetPasswordApi] that streams the password-reset
/// result to listeners.
///
/// Extends [RxResponseInt] with a `Map` payload: success pushes the decoded
/// response onto the stream, failure pushes the error and surfaces a toast.
class ResetPasswordRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to perform the reset request.
  ///
  /// Injectable: in production it defaults to the shared [ResetPasswordApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final ResetPasswordApi api;

  /// Creates the Rx wrapper.
  ///
  /// [api] defaults to the shared [ResetPasswordApi] singleton when omitted —
  /// so the production call sites in `api_access.dart` are unaffected — and
  /// tests may inject a fake. [empty] and [dataFetcher] are forwarded to
  /// [RxResponseInt].
  ResetPasswordRx({
    ResetPasswordApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? ResetPasswordApi.instance;

  /// The broadcast stream emitting the latest reset-password response or error.
  ValueStream get getFileData => dataFetcher.stream;

  /// Resets the password and reports whether the call succeeded.
  ///
  /// Forwards [email], [token], [password] and [confPass] to
  /// [ResetPasswordApi.resetPassword]. Returns `true` on success; on failure
  /// delegates to [handleErrorWithReturn], which shows a toast and returns
  /// `false`.
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confPass,
  }) async {
    try {
      final data = await api.resetPassword(
        email: email,
        token: token,
        password: password,
        confPass: confPass,
      );
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed reset request by surfacing a user-facing message.
  ///
  /// For a [DioException] with HTTP 400 (or any non-403 status) the backend
  /// `message` is shown via [ToastUtil]; HTTP 403 is intentionally silent. The
  /// [error] is always pushed onto [dataFetcher]; always returns `false`.
  @override
  handleErrorWithReturn(error) {
    if (error is DioException) {
      if (error.response!.statusCode == 400) {
        ToastUtil.showErrorMessage(error.response!.data["message"]);
      } else if (error.response!.data['code'] == 403) {
      } else {
        ToastUtil.showErrorMessage(error.response!.data['message']);
      }
    }
    dataFetcher.sink.addError(error);
    return false;
  }
}
