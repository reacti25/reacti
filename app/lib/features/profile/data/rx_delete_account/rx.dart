import 'dart:developer';

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/networks/stream_cleaner.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/streams.dart';

import '../../../../helpers/di.dart';
import '../../../../networks/rx_base.dart';
import 'api.dart';

final class DeleteAccountRx extends RxResponseInt<Map> {
  DeleteAccountRx({required super.empty, required super.dataFetcher});

  ValueStream get collectionStream => dataFetcher.stream;
  final api = DeleteAccountApi.instance;

  Future<bool> deleteAccount() async {
    try {
      final data = await api.deleteAccount();
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

  @override
  dynamic handleSuccessWithReturn(dynamic data) {
    appData.write(kKeyIsLoggedIn, true);
    dataFetcher.sink.add(data);
    return data;
  }
}
