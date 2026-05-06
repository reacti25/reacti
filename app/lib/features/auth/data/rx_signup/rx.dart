import 'package:achiar_expert_app/helpers/toast.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import 'api.dart';

final class SignUpRx extends RxResponseInt<Map> {
  String? errorMessage;
  final api = SignUpApi.instance;

  SignUpRx({required super.empty, required super.dataFetcher});

  ValueStream get getFileData => dataFetcher.stream;

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
