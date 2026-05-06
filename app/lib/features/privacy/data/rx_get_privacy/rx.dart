import 'dart:developer';

import 'package:achiar_expert_app/features/privacy/model/privacy_response.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/stream_cleaner.dart';
import 'api.dart';

final class GetPrivacyRx extends RxResponseInt<PrivacyResponse> {
  final api = GetPrivacyApi.instance;

  GetPrivacyRx({required super.empty, required super.dataFetcher});

  ValueStream get getPrivacyStream => dataFetcher.stream;

  Future<bool> getPrivacy() async {
    try {
      final data = await api.getPrivacy();
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      if (error.response!.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        log(error.response!.data["message"]);
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
