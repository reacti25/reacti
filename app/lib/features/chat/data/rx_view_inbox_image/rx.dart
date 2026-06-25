import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/streams.dart';

import '../../../../analytics/analytics_buckets.dart';
import '../../../../analytics/analytics_locator.dart';
import '../../../../analytics/events.dart';
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
  /// The underlying HTTP data source used to mark the image viewed.
  ///
  /// Injectable: in production it defaults to the shared
  /// [ViewInboxImageApi] singleton, but a test can pass a fake so the Rx
  /// logic can be exercised without real HTTP.
  final ViewInboxImageApi api;

  /// Creates the reactive source with its [empty] value and [dataFetcher].
  ///
  /// [api] defaults to the shared [ViewInboxImageApi] singleton when
  /// omitted — so the production call sites are unaffected — and tests
  /// may inject a fake.
  ViewInboxImageRx({
    ViewInboxImageApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? ViewInboxImageApi.instance;

  /// Stream of the latest view response for widgets to observe.
  ValueStream get getFileData => dataFetcher.stream;

  /// Marks the inbox image [id] as viewed and pushes the result onto the
  /// stream.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn] which returns `false`.
  Future<bool> viewInboxImage({required int id}) async {
    try {
      final data = await api.viewInboxImage(id: id);
      handleSuccessWithReturn(data);
      _trackMarkViewedResult(success: true);
      return true;
    } catch (error) {
      _trackMarkViewedResult(success: false, error: error);
      return handleErrorWithReturn(error);
    }
  }

  /// Records the mark-viewed outcome (metadata only). Fire-and-forget — it must
  /// never affect the patent flow this call gates.
  void _trackMarkViewedResult({required bool success, Object? error}) {
    try {
      analytics.track(Events.markViewedResult, {
        Props.scope: 'private',
        Props.result: success ? 'success' : 'failure',
        if (!success) Props.failureReason: failureReasonFromError(error),
      });
    } catch (_) {
      // Analytics must never disrupt mark-viewed.
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
