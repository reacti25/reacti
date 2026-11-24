import '../../../networks/dio/dio.dart';
import '../../../networks/endpoints.dart';

/// Tells the server the original sender has finished watching a one-time
/// reaction, which erases the whole exchange (the media and the reaction) from
/// the server and from both phones.
///
/// A top-level variable, like `reactionRecorder`, so tests can swap in a fake
/// and assert the call without a network.
///
/// Best-effort: if the call is lost (no signal, app killed) the server still
/// erases the exchange once its watch window lapses, so a failure is swallowed
/// and reported as `false`.
Future<bool> Function(int reactionMessageId) finishOneTimeExchange =
    _finishOverHttp;

/// The real call behind [finishOneTimeExchange].
Future<bool> _finishOverHttp(int reactionMessageId) async {
  try {
    await postHttp(EndPoints.finishOneTime(reactionMessageId));
    return true;
  } catch (_) {
    return false;
  }
}
