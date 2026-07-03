import 'package:dio/dio.dart';

import '../../../networks/dio/dio.dart';
import '../../../networks/endpoints.dart';

/// Thin HTTP wrapper for marking a 1:1 peer's messages read for the auth user.
///
/// Fire-and-forget: called when the peer's message arrives while the reader is
/// already sitting in the chat, so the sender's text double-check upgrades live
/// (the conversation fetch only marks read on open). The server broadcasts a
/// `MessageReadEvent` to the room. A failure must never disrupt the chat, so
/// callers ignore errors. Text status only — separate from the mark-viewed
/// patent path.
class InboxSeenApi {
  /// The single shared instance, created lazily on first access.
  static final InboxSeenApi _singleton = InboxSeenApi._internal();

  /// Private constructor enforcing the singleton pattern.
  InboxSeenApi._internal();

  /// The shared [InboxSeenApi] instance.
  static InboxSeenApi get instance => _singleton;

  /// Marks every message from peer [receiverId] read for the auth user.
  ///
  /// Returns `true` on HTTP 200, `false` on any other status or error — never
  /// throws.
  Future<bool> markSeen(int receiverId) async {
    try {
      final Response response = await getHttp(
        EndPoints.chatSeenAll(receiverId),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
