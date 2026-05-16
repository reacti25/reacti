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
import '../../model/group_inbox_response.dart';
import 'api.dart';

/// Reactive wrapper around [GetGroupInboxApi].
///
/// Extends [RxResponseInt] so the group inbox screen can observe the
/// loaded [GroupInboxResponse] through a stream.
final class GetGroupInboxRx extends RxResponseInt<GroupInboxResponse> {
  /// Creates the reactive source with its [empty] value and [dataFetcher].
  GetGroupInboxRx({required super.empty, required super.dataFetcher});

  /// Stream of the latest group inbox for widgets to observe.
  ValueStream get getGroupInboxStream => dataFetcher.stream;

  /// The underlying HTTP data source.
  final api = GetGroupInboxApi.instance;

  /// Loads the group inbox for [id] and pushes the result onto the stream.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn] which returns `false`.
  Future<bool> getGroupInboxMessage({required int id}) async {
    try {
      final data = await api.getGroupInboxMessage(id: id);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed group-inbox request.
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
