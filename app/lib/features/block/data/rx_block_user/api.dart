import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Thin HTTP wrapper for toggling the block state of another user.
///
/// The backend endpoint acts as a toggle, so the same call is used both to
/// block and to unblock a user. Implemented as a lazy singleton since it
/// holds no per-call state.
///
/// Not `final` so a test can supply a fake via `implements BlockUserApi`.
class BlockUserApi {
  /// The single shared instance, created lazily on first access.
  static final BlockUserApi _singleton = BlockUserApi._internal();

  /// Private constructor used to enforce the singleton pattern.
  BlockUserApi._internal();

  /// The shared [BlockUserApi] instance.
  static BlockUserApi get instance => _singleton;

  /// Toggles the block state for the user identified by [id].
  ///
  /// Returns the decoded JSON body as a [Map] on HTTP 200, throws the
  /// default [DataSource] failure for any other status code, and rethrows
  /// transport-level errors.
  Future<Map> blockUser({required int id}) async {
    try {
      Response response = await postHttp(EndPoints.blockAUser(id));
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
