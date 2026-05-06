import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/di.dart';
import '../../../../networks/dio/dio.dart';
import '../../model/login_response.dart';
import 'api.dart';

final class VerifySignupOtpRx extends RxResponseInt<LoginResponse> {
  String? errorMessage;
  final api = SignUpVerifyApi.instance;

  VerifySignupOtpRx({required super.empty, required super.dataFetcher});

  ValueStream get getFileData => dataFetcher.stream;

  Future<bool> verifySignupOtp({
    required String otp,
    required String email,
  }) async {
    try {
      final data = await api.verifySignupOtp(email: email, otp: otp);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

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

  @override
  handleErrorWithReturn(error) {
    if (error is DioException) {
      if (error.response!.statusCode == 400) {
        errorMessage = error.response!.data['message'];
      } else if (error.response!.data['code'] == 403) {
        errorMessage = error.response!.data['message'];
      } else {
        errorMessage = error.response!.data['message'];
      }
    }
    // log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
