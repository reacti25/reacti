import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/stream_cleaner.dart';
import 'api.dart';

final class MakeGroupAdminRx extends RxResponseInt<Map> {
  final api = MakeGroupAdminApi.instance;

  MakeGroupAdminRx({required super.empty, required super.dataFetcher});

  ValueStream get getGroupMediaStream => dataFetcher.stream;

  Future<bool> makeGroupAdmin({
    required int groupId,
    required int userId,
  }) async {
    try {
      final data = await api.makeGroupAdmin(groupId: groupId, userId: userId);
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
