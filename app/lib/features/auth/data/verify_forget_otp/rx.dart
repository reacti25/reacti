// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../../networks/rx_base.dart';
import '../../../../helpers/toast.dart';
import 'api.dart';

final class VerifyForgetPassRx extends RxResponseInt<Map> {
  String? errorMessage;
  String? resendToken;
  final api = VerifyForgetPassApi.instance;

  VerifyForgetPassRx({required super.empty, required super.dataFetcher});

  ValueStream get getFileData => dataFetcher.stream;

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
