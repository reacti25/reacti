// ignore_for_file: use_build_context_synchronously

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../../helpers/toast.dart';
import '../../../../../../networks/rx_base.dart';
import 'api.dart';

final class ResendForgetOtpRx extends RxResponseInt<Map> {
  String? errorMessage;
  final api = ResendForgetOtpApi.instance;

  ResendForgetOtpRx({required super.empty, required super.dataFetcher});

  ValueStream get getFileData => dataFetcher.stream;

  Future<bool> resendForgetOtp({required String email}) async {
    try {
      final data = await api.resendForgetOtp(email: email);
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
        errorMessage = error.response!.data['message'];
      } else {
        ToastUtil.showErrorMessage(error.response!.data['message']);
      }
    }
    dataFetcher.sink.addError(error);
    return false;
  }
}
