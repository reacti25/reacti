// ignore_for_file: use_build_context_synchronously

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../../helpers/toast.dart';
import '../../../../../../networks/rx_base.dart';
import 'api.dart';

/// Reactive wrapper around [ForgetPassApi] that streams the result of
/// requesting a password-reset OTP.
///
/// Extends [RxResponseInt] with a `Map` payload: success pushes the decoded
/// response onto the stream, failure pushes the error and surfaces a toast.
final class ForgetPassRx extends RxResponseInt<Map> {
  /// Last error message captured from a 403 response, if any.
  String? errorMessage;

  /// The underlying HTTP data source used to perform the request.
  final api = ForgetPassApi.instance;

  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to
  /// [RxResponseInt].
  ForgetPassRx({required super.empty, required super.dataFetcher});

  /// The broadcast stream emitting the latest forgot-password response or error.
  ValueStream get getFileData => dataFetcher.stream;

  /// Requests a password-reset OTP for [email] and reports whether it succeeded.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn], which shows a toast and returns `false`.
  Future<bool> forgetPassword({required String email}) async {
    try {
      final data = await api.forgetPassword(email: email);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed forgot-password request by surfacing a user-facing message.
  ///
  /// For a [DioException] with HTTP 400 (or any non-403 status) the backend
  /// `message` is shown via [ToastUtil]; HTTP 403 stores the message in
  /// [errorMessage] instead. The [error] is always pushed onto [dataFetcher];
  /// always returns `false`.
  @override
  handleErrorWithReturn(error) {
    if (error is DioException) {
      if (error.response!.statusCode == 400) {
        ToastUtil.showErrorMessage(error.response!.data["message"]);
      } else if (error.response!.data['code'] == 403) {
        errorMessage = error.response!.data['message'];
      } else {
        ToastUtil.showErrorMessage(error.response!.data['message']);
      }
    }
    dataFetcher.sink.addError(error);
    return false;
  }
}
