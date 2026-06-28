import 'package:dio/dio.dart';

import '../../../networks/dio/dio.dart';
import '../../../networks/endpoints.dart';

/// Thin HTTP wrapper for marking a group's messages read for the auth user.
///
/// Fire-and-forget: opening a group calls this so the conversation's unread
/// count clears (it writes the `group_message_reads` rows the chat-list
/// `unread_count` is computed from). A failure must never disrupt opening the
/// group, so callers ignore errors.
class GroupMarkReadApi {
  /// The single shared instance, created lazily on first access.
  static final GroupMarkReadApi _singleton = GroupMarkReadApi._internal();

  /// Private constructor enforcing the singleton pattern.
  GroupMarkReadApi._internal();

  /// The shared [GroupMarkReadApi] instance.
  static GroupMarkReadApi get instance => _singleton;

  /// Marks every message in [groupId] read for the authenticated user.
  ///
  /// Returns `true` on HTTP 200, `false` on any other status or error — never
  /// throws, so opening a group is never blocked by a read-receipt write.
  Future<bool> markRead(int groupId) async {
    try {
      final Response response = await postHttp(
        EndPoints.groupMarkRead(groupId),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
