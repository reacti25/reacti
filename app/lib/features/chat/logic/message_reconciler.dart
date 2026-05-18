import '../model/inbox_response.dart';
import '../model/group_inbox_response.dart';

/// Pure realtime-message reconciliation logic for the chat screens.
///
/// Extracted verbatim from the `onEvent` handlers of `InboxScreen` and
/// `GroupInboxScreen` so the optimistic-message matching can be unit-tested
/// without booting the widgets. Every function here is side-effect free:
/// no `setState`, no widgets, no I/O. The JSON parsing and the `setState`
/// wrapper stay in the screens; only the list-merge step lives here.
///
/// "Optimistic" messages are entries the screen inserted immediately on send,
/// before the server confirmed them. They are detected by an explicit
/// `isLocal == true` flag or by a temporary client-generated id greater than
/// `1000000000000`. When a realtime event arrives the screens look for a
/// matching optimistic entry and either reconcile it in place (keeping its
/// local file as a placeholder) or insert the incoming message at the head.

/// Threshold above which a message id is treated as a temporary,
/// client-generated optimistic id rather than a real server id.
const int _kOptimisticIdThreshold = 1000000000000;

/// Reconciles a realtime [incoming] one-to-one [Chat] into [current].
///
/// Returns the updated message list. If [incoming] matches an outstanding
/// optimistic local entry (using the exact predicate the inbox screen used
/// before this logic was extracted) that entry is replaced in place with the
/// server message — keeping the entry's `localPath` as a placeholder and
/// falling back to the old entry's `replyTo` when the server omits one.
/// Otherwise [incoming] is inserted at index 0.
///
/// Matching rules, identical to the original inline logic:
/// * The candidate must be optimistic: `isLocal == true` OR `id > 1e12`.
/// * `senderId` must match exactly.
/// * Media types match after coalescing `null` to `'text'`.
/// * For `'text'` messages the trimmed text must match exactly.
/// * For media messages, when both sides carry non-empty text the trimmed
///   text must match; otherwise the entry is considered a match.
///
/// @param  current   The screen's current message list (not mutated).
/// @param  incoming  The freshly parsed server message from the event.
/// @return  A new list with [incoming] merged in or prepended.
List<Chat> reconcileInboxMessage(List<Chat> current, Chat incoming) {
  // Work on a copy so the caller's list is never mutated in place.
  final result = List<Chat>.of(current);

  // Find the optimistic local message if it exists.
  final optimisticIndex = result.indexWhere((chat) {
    // Match if it's explicitly local OR if it has a temporary ID
    // (fast API response case).
    final isOptimistic =
        chat.isLocal == true || (chat.id ?? 0) > _kOptimisticIdThreshold;
    if (!isOptimistic) return false;

    if (chat.senderId != incoming.senderId) {
      return false;
    }

    // Match by media type first (treating null and 'text' as same).
    final localMediaType = chat.mediaType ?? 'text';
    final serverMediaType = incoming.mediaType ?? 'text';
    if (localMediaType != serverMediaType) {
      return false;
    }

    // If it's a text message, match text exactly (handle nulls).
    if (localMediaType == 'text') {
      return (chat.text ?? "").trim() == (incoming.text ?? "").trim();
    }

    // For media messages, they might have optional text.
    final localHasText = chat.text != null && chat.text!.isNotEmpty;
    final serverHasText = incoming.text != null && incoming.text != "";

    if (localHasText && serverHasText) {
      return chat.text!.trim() == incoming.text.toString().trim();
    }

    // If neither has text, or only one has text, we consider it a match.
    return true;
  });

  if (optimisticIndex != -1) {
    // Smoothly update the optimistic message with server data.
    // We keep the localPath to act as a placeholder for the network image.
    final localPath = result[optimisticIndex].localPath;
    result[optimisticIndex] = incoming.copyWith(
      isLocal: false,
      localPath: localPath,
      replyTo: incoming.replyTo ?? result[optimisticIndex].replyTo,
    );
  } else {
    result.insert(0, incoming);
  }

  return result;
}

/// Reconciles a realtime [incoming] group [Message] into [current].
///
/// Returns the updated message list. If [incoming] matches an outstanding
/// optimistic local entry (using the exact predicate the group inbox screen
/// used before this logic was extracted) that entry is replaced in place with
/// the server message — keeping the entry's `localPath` as a placeholder.
/// Otherwise [incoming] is inserted at index 0.
///
/// The matching rules mirror [reconcileInboxMessage]. Note one deliberate
/// difference preserved from the original screens: the group merge does not
/// apply a `replyTo` fallback — it copies exactly what the original
/// `GroupInboxScreen` handler did.
///
/// @param  current   The screen's current message list (not mutated).
/// @param  incoming  The freshly parsed server message from the event.
/// @return  A new list with [incoming] merged in or prepended.
List<Message> reconcileGroupMessage(List<Message> current, Message incoming) {
  // Work on a copy so the caller's list is never mutated in place.
  final result = List<Message>.of(current);

  // Find the optimistic local message if it exists.
  final optimisticIndex = result.indexWhere((msg) {
    // Match if it's explicitly local OR if it has a temporary ID
    // (fast API response case).
    final isOptimistic =
        msg.isLocal == true || (msg.id ?? 0) > _kOptimisticIdThreshold;
    if (!isOptimistic) return false;

    if (msg.senderId != incoming.senderId) {
      return false;
    }

    // Match by media type first (treating null and 'text' as same).
    final localMediaType = msg.mediaType ?? 'text';
    final serverMediaType = incoming.mediaType ?? 'text';
    if (localMediaType != serverMediaType) {
      return false;
    }

    // If it's a text message, match text exactly (handle nulls).
    if (localMediaType == 'text') {
      return (msg.text ?? "").trim() == (incoming.text ?? "").trim();
    }

    // For media messages, they might have optional text.
    final localHasText = msg.text != null && msg.text!.isNotEmpty;
    final serverHasText = incoming.text != null && incoming.text != "";

    if (localHasText && serverHasText) {
      return msg.text!.trim() == incoming.text.toString().trim();
    }

    // If neither has text, or only one has text, we consider it a match.
    return true;
  });

  if (optimisticIndex != -1) {
    // Smoothly update the optimistic message with server data.
    // We keep the localPath to act as a placeholder for the network image.
    final localPath = result[optimisticIndex].localPath;
    result[optimisticIndex] = incoming.copyWith(
      isLocal: false,
      localPath: localPath,
    );
  } else {
    result.insert(0, incoming);
  }

  return result;
}
