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
import '../../model/friend_list_response.dart';
import 'api.dart';

/// Reactive wrapper around [GetFriendListApi] that publishes the fetched
/// friend list on a broadcast stream.
///
/// Extends [RxResponseInt] with a [FriendListResponse] payload so the friend
/// list and any error are observable by widgets via [getFriendListStream].
class GetFriendListRx extends RxResponseInt<FriendListResponse> {
  /// The underlying HTTP data source used to perform the request.
  ///
  /// Injectable: in production it defaults to the shared [GetFriendListApi]
  /// singleton, but a test can pass a fake so the Rx logic can be exercised
  /// without real HTTP.
  final GetFriendListApi api;

  /// Creates the Rx data source.
  ///
  /// [api] defaults to the shared [GetFriendListApi] singleton when omitted —
  /// so production call sites are unaffected — and tests may inject a fake.
  /// [empty] and [dataFetcher] are forwarded to [RxResponseInt].
  GetFriendListRx({
    GetFriendListApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? GetFriendListApi.instance;

  /// The stream of friend-list responses, exposed read-only to consumers.
  ValueStream get getFriendListStream => dataFetcher.stream;

  /// Fetches the friend list and publishes it on [dataFetcher].
  ///
  /// Returns `true` once the response has been pushed to the stream. On
  /// failure [handleErrorWithReturn] reports the error and returns `false`.
  Future<bool> getFriendList() async {
    try {
      final data = await api.getFriendList();
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed friend-list fetch.
  ///
  /// Overrides [RxResponseInt.handleErrorWithReturn]: a `401` clears local
  /// data and routes to the login screen, while any other [DioException]
  /// surfaces the server message via a toast. The error is logged, added to
  /// [dataFetcher], and `false` is returned.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      // A 401 means the session expired; wipe local state and force re-login.
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
