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

/// Tells the server the viewer took a screenshot of the one-time message
/// [messageId] (only an iPhone can: Android blocks it), so the sender's tile
/// says "Screenshot attempt". A top-level variable for tests, like
/// [finishOneTimeExchange]. Best-effort: a lost call only means the sender
/// is not told.
Future<bool> Function(int messageId) reportOneTimeScreenshot =
    _reportScreenshotOverHttp;

/// The real call behind [reportOneTimeScreenshot].
Future<bool> _reportScreenshotOverHttp(int messageId) =>
    _post(EndPoints.oneTimeScreenshot(messageId));

/// Group version of [finishOneTimeExchange]: this member watched the one-time
/// media or reaction [messageId] to the end, so it is over for them only. The
/// server erases the exchange once every member is done (or after a day).
Future<bool> Function(int messageId) finishGroupOneTime =
    (id) => _post(EndPoints.finishGroupOneTime(id));

/// Group version of [reportOneTimeScreenshot].
Future<bool> Function(int messageId) reportGroupOneTimeScreenshot =
    (id) => _post(EndPoints.groupOneTimeScreenshot(id));

/// Best-effort POST to [path]: false instead of an error, as above.
Future<bool> _post(String path) async {
  try {
    await postHttp(path);
    return true;
  } catch (_) {
    return false;
  }
}
