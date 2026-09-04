import 'dart:developer';

import 'package:reacti_app/analytics/analytics_locator.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/rx_base.dart';
import '../../../../networks/stream_cleaner.dart';
import 'api.dart';

/// Reactive wrapper for leaving a group.
///
/// The menu item existed from the beginning; the action behind it did not —
/// `case 'leave'` only wrote a log line, so tapping Leave Group did nothing at
/// all. This is the missing half.
class LeaveGroupRx extends RxResponseInt<Map> {
  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to the base.
  ///
  /// [api] defaults to the shared [LeaveGroupApi] singleton when omitted — so
  /// production call sites are unaffected — and tests may inject a fake.
  LeaveGroupRx({
    LeaveGroupApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? LeaveGroupApi.instance;

  /// The HTTP data source used to leave a group.
  final LeaveGroupApi api;

  /// The broadcast stream of the most recent leave response.
  ValueStream get getFileData => dataFetcher.stream;

  /// Leaves group [groupId].
  ///
  /// Returns `true` once the response has been emitted, or `false` when
  /// [handleErrorWithReturn] handles a failure.
  Future<bool> leaveGroup({required int groupId}) async {
    try {
      final data = await api.leaveGroup(groupId: groupId);
      handleSuccessWithReturn(data);
      analytics.track(Events.groupLeft);
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
      if (error.response?.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        log('Leave group failed: ${error.response?.data}');
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
