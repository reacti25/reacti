import 'package:dio/dio.dart';

/// Shown when a request got no reply at all (offline, timeout, server down).
const kNoConnectionMessage =
    "Couldn't reach Reacti. Check your connection and try again.";

/// The message to show for a failed request: the server's own `message`, or
/// [kNoConnectionMessage] when there was no reply or it carried none.
///
/// Error handlers used to read the message through `error.response!`, which threw
/// a null-check error whenever the phone was offline (no response at all).
///
/// Example: `ToastUtil.showErrorMessage(apiErrorMessage(error));`
String apiErrorMessage(DioException error) {
  final data = error.response?.data;
  final message = data is Map ? data['message'] : null;
  return message is String ? message : kNoConnectionMessage;
}
