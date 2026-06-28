import '../../../networks/dio/dio.dart';
import '../../../networks/endpoints.dart';

/// Marks a received reaction as watched so its sender's grey→green dot updates.
///
/// Reactions are never blurred, so the patent `mark-viewed` flow never fired for
/// them and `is_viewed` stayed false — there was no "watched" signal. When the
/// recipient's app shows a reaction it calls the SAME mark-viewed endpoint
/// (1:1 or group), which sets `is_viewed` (and, server-side, broadcasts the
/// "seen"/"viewed" event). This does NOT trigger any recording — that is tied
/// to tapping a blurred-media placeholder, not to this API.
///
/// Fire-and-forget and idempotent on the server; failures are ignored so they
/// never disrupt rendering the reaction.
class ReactionWatchedApi {
  /// The single shared instance, created lazily on first access.
  static final ReactionWatchedApi _singleton = ReactionWatchedApi._internal();

  /// Private constructor enforcing the singleton pattern.
  ReactionWatchedApi._internal();

  /// The shared [ReactionWatchedApi] instance.
  static ReactionWatchedApi get instance => _singleton;

  /// Marks reaction [messageId] watched, routing to the group or 1:1 endpoint.
  Future<void> markWatched({
    required int messageId,
    required bool isGroup,
  }) async {
    try {
      await postHttp(
        isGroup
            ? EndPoints.viewGroupFile(messageId)
            : EndPoints.viewInboxImage(messageId),
      );
    } catch (_) {
      // Best-effort: a failed "watched" ping must never disrupt the UI.
    }
  }
}
