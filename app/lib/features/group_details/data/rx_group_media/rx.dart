import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/stream_cleaner.dart';
import '../../model/group_media_response.dart';
import 'api.dart';

/// Reactive wrapper that streams a group's media list to the UI.
///
/// Extends [RxResponseInt] so the latest [GroupMediaResponse] is published
/// through a [BehaviorSubject] consumed by the group-details media tab.
class GetGroupMediaRx extends RxResponseInt<GroupMediaResponse> {
  /// The HTTP data source used to fetch the group media list.
  ///
  /// Injectable: in production it defaults to the shared [GroupMediaApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final GroupMediaApi api;

  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to the base.
  ///
  /// [api] defaults to the shared [GroupMediaApi] singleton when omitted —
  /// so the production call sites are unaffected — and tests may inject a fake.
  GetGroupMediaRx({
    GroupMediaApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? GroupMediaApi.instance;

  /// The broadcast stream of the most recent group-media response.
  ValueStream get getGroupMediaStream => dataFetcher.stream;

  /// Loads the media of the group identified by [id] onto the stream.
  ///
  /// Returns `true` once a successful response has been emitted, or `false`
  /// when [handleErrorWithReturn] handles a failure.
  Future<bool> groupMediaList({required int id}) async {
    try {
      final data = await api.groupMediaList(id: id);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed request, returning `false` instead of rethrowing.
  ///
  /// On an HTTP 401 the local session is wiped and the user is sent back to
  /// the login screen; other [DioException]s only have their server message
  /// logged. The error is still pushed onto [dataFetcher] for listeners.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      // A 401 means the auth token is no longer valid: force a re-login.
      if (error.response!.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        log(error.response!.data["message"]);
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
