import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Thin HTTP wrapper for permanently deleting the signed-in user's account.
///
/// Implemented as a lazy singleton since it holds no per-call state.
final class DeleteAccountApi {
  /// The single shared instance, created lazily on first access.
  static final DeleteAccountApi _singleton = DeleteAccountApi._internal();

  /// Private constructor used to enforce the singleton pattern.
  DeleteAccountApi._internal();

  /// The shared [DeleteAccountApi] instance.
  static DeleteAccountApi get instance => _singleton;

  /// Issues a DELETE request that removes the current user's account.
  ///
  /// Returns the decoded JSON body as a [Map] on HTTP 200. Throws the
  /// default [DataSource] failure for any other status code and rethrows
  /// transport-level errors.
  Future<Map> deleteAccount() async {
    try {
      Response response = await deleteHttp(EndPoints.deleteAccount());
      if (response.statusCode == 200) {
        final data = json.decode(json.encode(response.data));
        return data;
      } else {
        log('Error: ${response.statusCode}');
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (e) {
      rethrow;
    }
  }
}
