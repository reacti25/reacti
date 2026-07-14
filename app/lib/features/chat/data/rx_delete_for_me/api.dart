import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for "delete for me" — hiding a message for the caller only.
///
/// A lazily-created singleton; the reactive [DeleteForMeRx] delegates here. Not
/// `final` so a test can supply a fake via `implements DeleteForMeApi`.
class DeleteForMeApi {
  /// The single shared instance backing [instance].
  static final DeleteForMeApi _singleton = DeleteForMeApi._internal();

  /// Private constructor enforcing the singleton pattern.
  DeleteForMeApi._internal();

  /// The shared [DeleteForMeApi] instance.
  static DeleteForMeApi get instance => _singleton;

  /// Hides the 1:1 message [messageId] for the caller only.
  Future<Map> deleteForMe({required int messageId}) async {
    Response response = await postHttp(EndPoints.deleteForMe(), {
      'message_id': messageId,
    });
    return _decode(response);
  }

  /// Hides the group message [messageId] for the caller only.
  Future<Map> deleteGroupForMe({required int messageId}) async {
    Response response = await postHttp(
      EndPoints.deleteGroupMessageForMe(messageId),
      {},
    );
    return _decode(response);
  }

  /// Returns the decoded body on HTTP 200; throws the default failure otherwise.
  Map _decode(Response response) {
    if (response.statusCode == 200) {
      return json.decode(json.encode(response.data));
    }
    log('Error: ${response.statusCode}');
    throw DataSource.DEFAULT.getFailure();
  }
}
