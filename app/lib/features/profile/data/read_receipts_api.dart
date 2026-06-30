import 'package:dio/dio.dart';

import '../../../networks/dio/dio.dart';
import '../../../networks/endpoints.dart';
import '../../../networks/exception_handler/data_source.dart';

/// Thin HTTP wrapper for updating the reciprocal read-receipts preference.
///
/// A one-shot PUT — there is no stream to expose, so this is a plain API
/// object rather than an `rx_*` data source. Lazy singleton; injectable for
/// tests via `implements ReadReceiptsApi`.
class ReadReceiptsApi {
  /// The single shared instance, created lazily on first access.
  static final ReadReceiptsApi _singleton = ReadReceiptsApi._internal();

  /// Private constructor enforcing the singleton pattern.
  ReadReceiptsApi._internal();

  /// The shared [ReadReceiptsApi] instance.
  static ReadReceiptsApi get instance => _singleton;

  /// Persists the read-receipts [enabled] preference server-side.
  ///
  /// Returns `true` on HTTP 200; throws the default [DataSource] failure for
  /// any other status and rethrows transport errors.
  Future<bool> update(bool enabled) async {
    try {
      final Response response = await putHttp(EndPoints.readReceipts(), {
        'read_receipts': enabled,
      });
      if (response.statusCode == 200) {
        return true;
      }
      throw DataSource.DEFAULT.getFailure();
    } catch (e) {
      rethrow;
    }
  }
}
