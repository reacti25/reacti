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

/// Reactive wrapper around [GetInboxMessageApi].
///
/// Extends [RxResponseInt] so the chat inbox screen can observe the
/// loaded [InboxResponse] through a stream. Also caches the block
/// status and room id from the most recent load for quick access.
class GetInboxMessageRx extends RxResponseInt<InboxResponse> {
  /// Whether the other participant has blocked this conversation.
  ///
  /// Cached from the last successful [getInboxMessage] call; `null`
  /// until the first load completes.
  bool? isBlocked;

  /// The chat room id from the last successful [getInboxMessage] call.
  ///
  /// `null` until the first load completes.
  int? roomId;

  /// The underlying HTTP data source used to load the inbox.
  ///
  /// Injectable: in production it defaults to the shared
  /// [GetInboxMessageApi] singleton, but a test can pass a fake so the
  /// Rx logic can be exercised without real HTTP.
  final GetInboxMessageApi api;

  /// Creates the reactive source with its [empty] value and [dataFetcher].
  ///
  /// [api] defaults to the shared [GetInboxMessageApi] singleton when
  /// omitted — so the production call sites are unaffected — and tests
  /// may inject a fake.
  GetInboxMessageRx({
    GetInboxMessageApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? GetInboxMessageApi.instance;

  /// Stream of the latest inbox response for widgets to observe.
  ValueStream get getInboxStream => dataFetcher.stream;

  /// Loads the inbox for [id] and pushes the result onto the stream.
  ///
  /// Also caches [isBlocked] and [roomId] from the response. Returns
  /// `true` on success; on failure delegates to [handleErrorWithReturn]
  /// which returns `false`.
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

  /// Handles a failed inbox request.
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
