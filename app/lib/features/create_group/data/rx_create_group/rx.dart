import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../analytics/activation_funnel.dart';
import '../../../../analytics/events.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/stream_cleaner.dart';
import 'api.dart';

/// Reactive wrapper for the create-group action.
///
/// Extends [RxResponseInt] so the raw response map is published through a
/// [BehaviorSubject] after a group is created.
class CreateGroupRx extends RxResponseInt<Map> {
  /// The HTTP data source used to create a group.
  ///
  /// Injectable: in production it defaults to the shared [CreateGroupApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final CreateGroupApi api;

  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to the base.
  ///
  /// [api] defaults to the shared [CreateGroupApi] singleton when omitted —
  /// so the production call sites are unaffected — and tests may inject a fake.
  CreateGroupRx({
    CreateGroupApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? CreateGroupApi.instance;

  /// The broadcast stream of the most recent create-group response.
  ValueStream get getFileData => dataFetcher.stream;

  /// Creates a group named [name] with [memberIds], optional [description]
  /// and [avatar].
  ///
  /// Returns `true` once the response has been emitted, or `false` when
  /// [handleErrorWithReturn] handles a failure.
  Future<bool> createGroup({
    required String name,
    String? description,
    required List<int?> memberIds,
    XFile? avatar,
  }) async {
    try {
      final data = await api.createGroup(
        name: name,
        description: description,
        avatar: avatar,
        memberIds: memberIds,
      );
      await ActivationFunnel.reach(Events.groupCreated);
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
