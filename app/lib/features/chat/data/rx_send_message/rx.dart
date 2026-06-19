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

/// Reactive wrapper around [SendMessageApi].
///
/// Extends [RxResponseInt] so the chat screen can observe the send
/// result through a stream. Used by the patent flow to upload
/// `type: "reaction"` clips to a one-to-one conversation.
//
// `class` (not `final class`) so the patent-flow widget test can swap
// the global instance with a subclass that returns canned data.
// See app/test/features/chat/widget/patent_flow_interactive_test.dart.
class SendMessageRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to send the message.
  ///
  /// Injectable: in production it defaults to the shared [SendMessageApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final SendMessageApi api;

  /// Creates the reactive source with its [empty] value and [dataFetcher].
  ///
  /// [api] defaults to the shared [SendMessageApi] singleton when omitted
  /// — so the production call sites are unaffected — and tests may inject
  /// a fake.
  SendMessageRx({
    SendMessageApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? SendMessageApi.instance;

  /// Stream of the latest send response for widgets to observe.
  ValueStream get getChatStream => dataFetcher.stream;

  /// Sends a chat message and pushes the result onto the stream.
  ///
  /// Forwards [id], [message], [type], [file], [onSendProgress] and
  /// [replyToId] to [SendMessageApi.sendMessage]. Returns `true` on
  /// success; on failure delegates to [handleErrorWithReturn] which
  /// returns `false`.
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
      final data = await api.sendMessage(
        id: id,
        message: message,
        file: file,
        type: type,
        onSendProgress: onSendProgress,
        replyToId: replyToId,
      );
      handleSuccessWithReturn(data);

      trackMessageSend(
        scope: 'private',
        type: type,
        file: file,
        ms: sendStopwatch.elapsedMilliseconds,
        success: true,
      );
      return true;
    } catch (error) {
      trackMessageSend(
        scope: 'private',
        type: type,
        file: file,
        ms: sendStopwatch.elapsedMilliseconds,
        success: false,
      );
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed message send.
  ///
  /// On an HTTP 401 the local session is cleared and the user is sent
  /// back to the login screen; other [DioException]s surface a toast
  /// with the server message (falling back to a generic string). The
  /// [error] is logged and forwarded to the stream, and `false` is
  /// returned to signal failure.
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
