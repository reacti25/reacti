// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../../networks/rx_base.dart';
import '../../../../helpers/toast.dart';
import 'api.dart';

/// Reactive wrapper around [VerifyForgetPassApi] that streams the result of
/// confirming a forgot-password OTP.
///
/// Extends [RxResponseInt] with a `Map` payload. On success it also captures
/// the reset token returned by the backend so the reset-password screen can
/// authorize the final password change.
final class VerifyForgetPassRx extends RxResponseInt<Map> {
  /// Last error message captured from a 403 response, if any.
  String? errorMessage;

  /// Reset token returned on a successful verification; consumed by the
  /// reset-password step to authorize the password change.
  String? resendToken;

  /// The underlying HTTP data source used to perform the verification request.
  final api = VerifyForgetPassApi.instance;

  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to
  /// [RxResponseInt].
  VerifyForgetPassRx({required super.empty, required super.dataFetcher});

  /// The broadcast stream emitting the latest verification response or error.
  ValueStream get getFileData => dataFetcher.stream;

  /// Verifies the forgot-password [otp] for [email] and reports success.
  ///
  /// On success the response `token` is stored in [resendToken]. Returns
  /// `true` on success; on failure delegates to [handleErrorWithReturn], which
  /// returns `false`.
  Future<bool> verifyForgetPass({
    required String email,
    required String otp,
  }) async {
    try {
      final data = await api.verifyForgetPass(email: email, otp: otp);
      handleSuccessWithReturn(data);
      resendToken = data['token'];
      log("Forget Token is ============> $resendToken");
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed OTP verification by surfacing a user-facing message.
  ///
  /// For a [DioException] with HTTP 400 the backend `message` is shown via
  /// [ToastUtil]; HTTP 403 stores the message in [errorMessage] instead. The
  /// [error] is always pushed onto [dataFetcher]; always returns `false`.
  @override
  handleErrorWithReturn(error) {
    if (error is DioException) {
      if (error.response!.statusCode == 400) {
        ToastUtil.showErrorMessage(error.response!.data["message"]);
        // ToastUtil.showShortToast(error.response!.data["message"]);
      } else if (error.response!.data['code'] == 403) {
        errorMessage = error.response!.data['message'];
      } else {
        // ToastUtil.showLongToast(error.response!.data['message']);
      }
    }
    dataFetcher.sink.addError(error);
    return false;
  }
}
