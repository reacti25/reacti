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

/// Reactive wrapper around [SendGroupMessageApi].
///
/// Extends [RxResponseInt] so the group chat screen can observe the
/// send result through a stream. Used by the patent flow to upload
/// `type: "reaction"` clips to a group conversation.
final class SendGroupMessageRx extends RxResponseInt<Map> {
  /// Creates the reactive source with its [empty] value and [dataFetcher].
  SendGroupMessageRx({required super.empty, required super.dataFetcher});

  /// Stream of the latest send response for widgets to observe.
  ValueStream get getFileData => dataFetcher.stream;

  /// The underlying HTTP data source.
  final api = SendGroupMessageApi.instance;

  /// Sends a group message and pushes the result onto the stream.
  ///
  /// Forwards [id], [message], [type], [file], [onSendProgress] and
  /// [replyToId] to [SendGroupMessageApi.sendGroupMessage]. Returns
  /// `true` on success; on failure delegates to [handleErrorWithReturn]
  /// which returns `false`.
  Future<bool> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    try {
      final data = await api.sendGroupMessage(
        id: id,
        message: message,
        file: file,
        type: type,
        replyToId: replyToId,
        onSendProgress: onSendProgress,
      );
      handleSuccessWithReturn(data);

      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed group message send.
  ///
  /// On an HTTP 401 the local session is cleared and the user is sent
  /// back to the login screen; other [DioException]s surface a toast
  /// with the server message. The [error] is logged and forwarded to
  /// the stream, and `false` is returned to signal failure.
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
