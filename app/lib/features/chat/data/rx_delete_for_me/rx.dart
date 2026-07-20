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
import 'api.dart';

/// Reactive wrapper around [DeleteForMeApi] for "delete for me".
class DeleteForMeRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source; injectable for tests.
  final DeleteForMeApi api;

  /// Creates the reactive source with its [empty] value and [dataFetcher].
  DeleteForMeRx({
    DeleteForMeApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? DeleteForMeApi.instance;

  /// Stream of the latest response for widgets to observe.
  ValueStream get getChatStream => dataFetcher.stream;

  /// Hides the 1:1 message [messageId] for the caller. Returns success.
  Future<bool> deleteForMe({required int messageId}) async {
    try {
      handleSuccessWithReturn(await api.deleteForMe(messageId: messageId));
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Hides the group message [messageId] for the caller. Returns success.
  Future<bool> deleteGroupForMe({required int messageId}) async {
    try {
      handleSuccessWithReturn(await api.deleteGroupForMe(messageId: messageId));
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failure: 401 logs out; other errors toast the server message.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        ToastUtil.showErrorMessage(
          error.response?.data["message"] ?? "Couldn't delete the message",
        );
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
