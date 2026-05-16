import 'package:achiar_expert_app/helpers/toast.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import 'api.dart';

/// Reactive wrapper around [SignUpApi] that streams the registration result.
///
/// Extends [RxResponseInt] with a `Map` payload: success pushes the decoded
/// response onto the stream, failure pushes the error and surfaces a toast.
final class SignUpRx extends RxResponseInt<Map> {
  /// Last error message captured from a failed registration response, if any.
  String? errorMessage;

  /// The underlying HTTP data source used to perform the registration request.
  final api = SignUpApi.instance;

  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to
  /// [RxResponseInt].
  SignUpRx({required super.empty, required super.dataFetcher});

  /// The broadcast stream emitting the latest signup response or error.
  ValueStream get getFileData => dataFetcher.stream;

  /// Registers a new account and reports whether the call succeeded.
  ///
  /// Forwards [fName], [lName], [email], [phone], [password] and
  /// [confPassword] to [SignUpApi.signup]. Returns `true` on success; on
  /// failure delegates to [handleErrorWithReturn], which shows a toast and
  /// returns `false`.
  Future<bool> signup({
    required String fName,
    required String lName,
    required String email,
    required String phone,
    required String password,
    required String confPassword,
  }) async {
    try {
      final data = await api.signup(
        fName: fName,
        lName: lName,
        email: email,
        phone: phone,
        password: password,
        confPassword: confPassword,
      );
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed registration by surfacing the backend error message.
  ///
  /// For any [DioException] the backend `message` is stored in [errorMessage]
  /// and shown via [ToastUtil]. The [error] is always pushed onto
  /// [dataFetcher]; always returns `false`.
  @override
  handleErrorWithReturn(error) {
    if (error is DioException) {
      if (error.response!.statusCode == 400) {
        errorMessage = error.response!.data['message'];
        ToastUtil.showErrorMessage(errorMessage ?? "");
      } else if (error.response!.data['code'] == 403) {
        errorMessage = error.response!.data['message'];
        ToastUtil.showErrorMessage(errorMessage ?? "");
      } else {
        errorMessage = error.response!.data['message'];
        ToastUtil.showErrorMessage(errorMessage ?? "");
      }
    }
    // log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
