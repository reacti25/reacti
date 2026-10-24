import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/streams.dart';

import '../../../../analytics/chat_send_analytics.dart';
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
class SendGroupMessageRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to send the group message.
  ///
  /// Injectable: in production it defaults to the shared
  /// [SendGroupMessageApi] singleton, but a test can pass a fake so the
  /// Rx logic can be exercised without real HTTP.
  final SendGroupMessageApi api;

  /// Creates the reactive source with its [empty] value and [dataFetcher].
  ///
  /// [api] defaults to the shared [SendGroupMessageApi] singleton when
  /// omitted — so the production call sites are unaffected — and tests
  /// may inject a fake.
  SendGroupMessageRx({
    SendGroupMessageApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? SendGroupMessageApi.instance;

  /// Stream of the latest send response for widgets to observe.
  ValueStream get getFileData => dataFetcher.stream;

  /// Server id of the most recently created message (`data.message.id`),
  /// mirroring [SendMessageRx.lastCreatedId]. The group screen adopts it into
  /// its optimistic reaction right away so the post-reaction thread re-sync
  /// (react-to-unlock) dedupes by id instead of showing the reaction twice
  /// until the send echo reconciles the temp id.
  /// ponytail: single field on the shared instance, same caveat as the 1:1 one.
  int? lastCreatedId;

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
    // Measure the send for analytics only — never alters the send itself.
    final sendStopwatch = Stopwatch()..start();
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
      lastCreatedId = _extractCreatedId(data);

      trackMessageSend(
        scope: 'group',
        type: type,
        file: file,
        ms: sendStopwatch.elapsedMilliseconds,
        success: true,
      );
      return true;
    } catch (error) {
      trackMessageSend(
        scope: 'group',
        type: type,
        file: file,
        ms: sendStopwatch.elapsedMilliseconds,
        success: false,
        error: error,
      );
      return handleErrorWithReturn(error);
    }
  }

  /// Best-effort extraction of the created message id from the send [response]
  /// envelope (`data.message.id`); null when the shape is unexpected.
  int? _extractCreatedId(dynamic response) {
    try {
      final id = response['data']?['message']?['id'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
      return null;
    } catch (_) {
      return null;
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
