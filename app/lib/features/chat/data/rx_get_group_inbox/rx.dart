import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/streams.dart';

import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../helpers/toast.dart';
import '../../../../networks/rx_base.dart';
import '../../../../networks/stream_cleaner.dart';
import '../../model/group_inbox_response.dart';
import 'api.dart';

final class GetGroupInboxRx extends RxResponseInt<GroupInboxResponse> {
  GetGroupInboxRx({required super.empty, required super.dataFetcher});

  ValueStream get getGroupInboxStream => dataFetcher.stream;
  final api = GetGroupInboxApi.instance;

  Future<bool> getGroupInboxMessage({required int id}) async {
    try {
      final data = await api.getGroupInboxMessage(id: id);
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
        ToastUtil.showErrorMessage(error.response!.data["message"]);
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
