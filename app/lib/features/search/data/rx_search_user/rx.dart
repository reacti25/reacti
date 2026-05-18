import 'dart:developer';

import 'package:achiar_expert_app/features/search/model/all_user_response.dart';
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

/// Reactive wrapper around [SearchApi] that streams user-search results.
///
/// Extends [RxResponseInt] so search results ([AllUserResponse]) flow through
/// a [BehaviorSubject] that the search screen rebuilds from.
class SearchUserRx extends RxResponseInt<AllUserResponse> {
  /// The API data source used to perform the search request.
  ///
  /// Injectable: in production it defaults to the shared [SearchApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final SearchApi api;

  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to the base.
  ///
  /// [api] defaults to the shared [SearchApi] singleton when omitted — so
  /// the production call sites are unaffected — and tests may inject a
  /// fake.
  SearchUserRx({
    SearchApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? SearchApi.instance;

  /// Broadcast stream emitting the latest [AllUserResponse] or an error.
  ValueStream get getSearchStream => dataFetcher.stream;

  /// Runs a user search for [search] and pushes results onto [getSearchStream].
  ///
  /// Returns `true` on success, otherwise delegates to [handleErrorWithReturn]
  /// which returns `false`.
  Future<bool> searchUser({required String search}) async {
    try {
      final data = await api.searchUser(search: search);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed user search.
  ///
  /// On an HTTP 401 the session is wiped via [totalDataClean] and the user is
  /// sent to login. Other [DioException]s surface a toast with the backend
  /// message. The [error] is pushed onto [dataFetcher]; always returns `false`.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      if (error.response!.statusCode == 401) {
        // A 401 means the token is no longer valid: clear the session and
        // force re-authentication rather than retrying.
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
