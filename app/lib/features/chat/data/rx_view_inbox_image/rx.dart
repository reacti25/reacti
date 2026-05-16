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

/// Reactive wrapper around [ViewInboxImageApi].
///
/// Extends [RxResponseInt] so the chat screen can observe the
/// mark-viewed result through a stream. This call is the trigger point
/// for the patent flow: once it succeeds the receiver-message widget
/// starts the silent reaction recording.
//
// `class` (not `final class`) so the patent-flow widget test can swap
// the global instance with a subclass that returns canned data.
// See app/test/features/chat/widget/patent_flow_interactive_test.dart.
class ViewInboxImageRx extends RxResponseInt<Map> {
  /// Creates the reactive source with its [empty] value and [dataFetcher].
  ViewInboxImageRx({required super.empty, required super.dataFetcher});

  /// Stream of the latest view response for widgets to observe.
  ValueStream get getFileData => dataFetcher.stream;

  /// The underlying HTTP data source.
  final api = ViewInboxImageApi.instance;

  /// Marks the inbox image [id] as viewed and pushes the result onto the
  /// stream.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn] which returns `false`.
  Future<bool> viewInboxImage({required int id}) async {
    try {
      final data = await api.viewInboxImage(id: id);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed mark-viewed request.
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
