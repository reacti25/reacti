import 'dart:developer';

import 'package:camera/camera.dart';
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

final class SendMessageRx extends RxResponseInt<Map> {
  SendMessageRx({required super.empty, required super.dataFetcher});

  ValueStream get getChatStream => dataFetcher.stream;
  final api = SendMessageApi.instance;

  Future<bool> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    try {
      final data = await api.sendMessage(
        id: id,
        message: message,
        file: file,
        type: type,
        onSendProgress: onSendProgress,
        replyToId: replyToId,
      );
      handleSuccessWithReturn(data);

      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        ToastUtil.showErrorMessage(
          error.response?.data["message"] ?? "An error occurred",
        );
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
