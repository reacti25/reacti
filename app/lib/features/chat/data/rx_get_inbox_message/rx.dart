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
import '../../model/inbox_response.dart';
import 'api.dart';

final class GetInboxMessageRx extends RxResponseInt<InboxResponse> {
  bool? isBlocked;
  int? roomId;
  GetInboxMessageRx({required super.empty, required super.dataFetcher});

  ValueStream get getInboxStream => dataFetcher.stream;
  final api = GetInboxMessageApi.instance;

  Future<bool> getInboxMessage({required int id}) async {
    try {
      final data = await api.getInboxMessage(id: id);
      isBlocked = data.data?.isBlocked;
      roomId = data.data?.room?.id;
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
