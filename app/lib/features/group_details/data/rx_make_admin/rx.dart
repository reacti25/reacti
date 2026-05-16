import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/stream_cleaner.dart';
import 'api.dart';

/// Reactive wrapper for the "make admin" action.
///
/// Extends [RxResponseInt] so the raw response map is published through a
/// [BehaviorSubject] after a member is promoted.
final class MakeGroupAdminRx extends RxResponseInt<Map> {
  /// The HTTP data source used to promote a member.
  final api = MakeGroupAdminApi.instance;

  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to the base.
  MakeGroupAdminRx({required super.empty, required super.dataFetcher});

  /// The broadcast stream of the most recent "make admin" response.
  ValueStream get getGroupMediaStream => dataFetcher.stream;

  /// Promotes member [userId] in group [groupId] to admin.
  ///
  /// Returns `true` once the response has been emitted, or `false` when
  /// [handleErrorWithReturn] handles a failure.
  Future<bool> makeGroupAdmin({
    required int groupId,
    required int userId,
  }) async {
    try {
      final data = await api.makeGroupAdmin(groupId: groupId, userId: userId);
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
