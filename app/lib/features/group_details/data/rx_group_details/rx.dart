import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/stream_cleaner.dart';
import '../../model/group_details_response.dart';
import 'api.dart';

/// Reactive wrapper that streams group-details state to the UI.
///
/// Extends [RxResponseInt] so the latest [GroupDetailsResponse] is published
/// through a [BehaviorSubject] that screens can listen to via [StreamBuilder].
class GroupDetailsRx extends RxResponseInt<GroupDetailsResponse> {
  /// The HTTP data source used to fetch group details.
  ///
  /// Injectable: in production it defaults to the shared [GroupDetailsApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final GroupDetailsApi api;

  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to the base.
  ///
  /// [api] defaults to the shared [GroupDetailsApi] singleton when omitted —
  /// so the production call sites are unaffected — and tests may inject a fake.
  GroupDetailsRx({
    GroupDetailsApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? GroupDetailsApi.instance;

  /// The broadcast stream of the most recent group-details response.
  ValueStream get getGroupDetailsStream => dataFetcher.stream;

  /// Loads the group identified by [id] and pushes the result onto the stream.
  ///
  /// Returns `true` once a successful response has been emitted, or `false`
  /// when [handleErrorWithReturn] handles a failure.
  Future<bool> getGroupDetails({required int id}) async {
    try {
      final data = await api.groupDetails(id: id);
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
  /// logged. The error is still pushed onto [dataFetcher] so listening
  /// widgets can react to it.
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
