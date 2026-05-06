// ignore_for_file: use_build_context_synchronously

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../../helpers/toast.dart';
import '../../../../../../networks/rx_base.dart';
import 'api.dart';

final class ResetPasswordRx extends RxResponseInt<Map> {
  final api = ResetPasswordApi.instance;

  ResetPasswordRx({required super.empty, required super.dataFetcher});

  ValueStream get getFileData => dataFetcher.stream;

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
