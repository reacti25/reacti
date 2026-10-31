import 'dart:math' show max;

// Both models declare a `Pagination` and a `ReplyTo`. Only the group
// `Pagination` is used here (for isCursorGroupResponse) and only the 1:1
// `ReplyTo` (in parseRealtimeInboxChat), so hide the clashing halves.
import '../model/inbox_response.dart' hide Pagination;
import '../model/group_inbox_response.dart' hide ReplyTo;
// The 1:1 Pagination is hidden above (group's is the default); bring it back
// under a prefix for isCursorInboxResponse.
import '../model/inbox_response.dart' as inbox show Pagination;

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

/// The optimistic [local] message once the server saved it: its real
/// [serverId] (the temp id stays if the reply carried none), sent at [nowUtc]
/// unless it already has a send time, and no longer local.
///
/// Without this a just-sent message kept its temp id and no send time until
/// the chat was reopened: Edit stayed hidden, and Delete, Forward and Reply
/// sent the server an id it never had. Found by the testing lab (#542).
Chat confirmSentChat(
  Chat local, {
  required int? serverId,
  required DateTime nowUtc,
}) => local.copyWith(
  id: serverId ?? local.id,
  sentAtUtc: local.sentAtUtc ?? nowUtc,
  isLocal: false,
);

/// Threshold above which a message id is treated as a temporary,
/// client-generated optimistic id rather than a real server id.
const int _kOptimisticIdThreshold = 1000000000000;

/// Parses a realtime 1:1 [messageData] envelope (the `MessageSendEvent`
/// payload shaped `{ "chat": { ... } }`) into a [Chat].
///
/// MUST stay in lockstep with the group parse (which already carries the
/// type): a received message keeps its `message_type`. Dropping it makes a
/// received reaction render as plain media and — the load-bearing part — the
/// media sender's on-play `markWatched` is guarded by `messageType ==
/// 'reaction'`, so without the type it never fires and the reaction author's
/// grey→green dot never updates live (it only recovered on a re-enter, which
/// re-fetches the real type).
Chat parseRealtimeInboxChat(Map messageData) => Chat(
  id: messageData['chat']['id'],
  senderId: messageData['chat']['sender_id'],
  receiverId: messageData['chat']['receiver_id'],
  text: messageData['chat']['text'],
  file: messageData['chat']['file'],
  humanizeDate: messageData['chat']['humanize_date'],
  sentAtUtc: messageData['chat']['created_at_utc'] == null
      ? null
      : DateTime.tryParse(messageData['chat']['created_at_utc'])?.toUtc(),
  isBlurred:
      (messageData['chat']['is_blurred'] == true ||
          messageData['chat']['is_blurred'] == 1)
      ? 1
      : 0,
  mediaType: messageData['chat']['media_type'],
  messageType: messageData['chat']['message_type'],
  sender: Receiver(
    id: messageData['chat']['sender']['id'],
    firstName: messageData['chat']['sender']['first_name'],
    lastName: messageData["chat"]['sender']['last_name'],
    avatar: messageData['chat']['sender']['avatar'],
  ),
  receiver: Receiver(
    id: messageData['chat']['receiver']['id'],
    firstName: messageData['chat']['receiver']['first_name'],
    lastName: messageData["chat"]['receiver']['last_name'],
    avatar: messageData['chat']['receiver']['avatar'],
  ),
  replyTo: messageData['chat']['reply_to'] == null
      ? null
      : ReplyTo(
          id: messageData['chat']['reply_to']['id'],
          senderId: messageData['chat']['reply_to']['sender_id'],
          text: messageData['chat']['reply_to']['text'],
          file: messageData['chat']['reply_to']['file'],
          mediaType: messageData['chat']['reply_to']['media_type'],
          isBlurred: messageData['chat']['reply_to']['is_blurred'],
          sender: messageData['chat']['reply_to']['sender'] == null
              ? null
              : Receiver(
                  id: messageData['chat']['reply_to']['sender']['id'],
                  firstName:
                      messageData['chat']['reply_to']['sender']['first_name'],
                  lastName:
                      messageData['chat']['reply_to']['sender']['last_name'],
                  avatar: messageData['chat']['reply_to']['sender']['avatar'],
                ),
        ),
);

/// Whether a pending entry sent by [localSender] with [localType] and
/// [localText] is the send that a server echo of the same three confirms.
///
/// Type `null` counts as `'text'`, text `null` as empty. The text must match
/// for media too: a caption-less echo once claimed the captioned bubble of a
/// later photo in the same batch, so the sender's photos showed out of place
/// and one went missing until the chat was reopened.
bool _isSameSend(
  (int?, String?, String?) local,
  (int?, String?, String?) server,
) =>
    local.$1 == server.$1 &&
    (local.$2 ?? 'text') == (server.$2 ?? 'text') &&
    (local.$3 ?? '').trim() == (server.$3 ?? '').trim();

/// Reconciles a realtime [incoming] one-to-one [Chat] into [current].
///
/// Returns the updated message list:
/// * [incoming] already in the list by its real id (the send response's id
///   was adopted, or a re-sync landed first): refreshed in place, never twice.
/// * Otherwise the OLDEST optimistic entry that [_isSameSend] matches is
///   replaced in place, keeping its `localPath` as a placeholder and its
///   `replyTo` when the server omits one. Oldest, since a batch uploads in
///   order and its echoes arrive in that order.
/// * Otherwise [incoming] is inserted at index 0.
///
/// @param  current   The screen's current message list, newest first (not mutated).
/// @param  incoming  The freshly parsed server message from the event.
/// @return  A new list with [incoming] merged in or prepended.
List<Chat> reconcileInboxMessage(List<Chat> current, Chat incoming) {
  final result = List<Chat>.of(current);
  final server = (incoming.senderId, incoming.mediaType, incoming.text);

  var index = incoming.id == null
      ? -1
      : result.indexWhere((c) => c.id == incoming.id);
  if (index == -1) {
    index = result.lastIndexWhere(
      (c) =>
          _isOptimisticChat(c) &&
          _isSameSend((c.senderId, c.mediaType, c.text), server),
    );
  }

  if (index == -1) {
    result.insert(0, incoming);
  } else {
    result[index] = incoming.copyWith(
      isLocal: false,
      localPath: result[index].localPath,
      replyTo: incoming.replyTo ?? result[index].replyTo,
    );
  }
  return result;
}

/// Reconciles a realtime [incoming] group [Message] into [current].
///
/// Same rules as [reconcileInboxMessage], except that the group merge keeps
/// no `replyTo` fallback (as the original `GroupInboxScreen` handler did).
///
/// @param  current   The screen's current message list, newest first (not mutated).
/// @param  incoming  The freshly parsed server message from the event.
/// @return  A new list with [incoming] merged in or prepended.
List<Message> reconcileGroupMessage(List<Message> current, Message incoming) {
  final result = List<Message>.of(current);
  final server = (incoming.senderId, incoming.mediaType, incoming.text);

  var index = incoming.id == null
      ? -1
      : result.indexWhere((m) => m.id == incoming.id);
  if (index == -1) {
    index = result.lastIndexWhere(
      (m) =>
          _isOptimisticMessage(m) &&
          _isSameSend((m.senderId, m.mediaType, m.text), server),
    );
  }

  if (index == -1) {
    result.insert(0, incoming);
  } else {
    result[index] = incoming.copyWith(
      isLocal: false,
      localPath: result[index].localPath,
    );
  }
  return result;
}

/// The highest of [ids] (server ids grow over time), or 0 for none.
int _newestId(Set<int> ids) => ids.fold(0, max);

/// Whether [chat] is an optimistic, not-yet-server-confirmed entry — the same
/// predicate the reconcilers use: an explicit `isLocal` flag or a temporary
/// client-generated id above [_kOptimisticIdThreshold].
bool _isOptimisticChat(Chat chat) =>
    chat.isLocal == true || (chat.id ?? 0) > _kOptimisticIdThreshold;

/// Whether [msg] is an optimistic, not-yet-server-confirmed group entry.
bool _isOptimisticMessage(Message msg) =>
    msg.isLocal == true || (msg.id ?? 0) > _kOptimisticIdThreshold;

/// Rebuilds the displayed 1:1 thread from a freshly fetched [serverNewestFirst]
/// list, keeping any optimistic (still-uploading) local entries the server
/// doesn't know about yet.
///
/// Replaces the old `if (cList.isEmpty)` guard, which populated the list once
/// and then ignored later server responses — so on re-entry the screen locked
/// onto the stale value the shared stream replays and dropped messages sent in
/// the meantime. Confirmed messages always come from the server (the source of
/// truth); only genuinely in-flight optimistic entries are preserved, and only
/// when the server list doesn't already contain them (so a confirmed message
/// never shows twice).
///
/// Also kept: messages newer than the newest one fetched. A live message that
/// landed while the fetch was in flight is missing from the server's older
/// snapshot, and dropping it made a received message vanish until the chat
/// was reopened (found by the testing lab, #542).
///
/// @param  current            The screen's current list (newest-first).
/// @param  serverNewestFirst  The freshly fetched server messages, newest-first.
/// @return  Surviving optimistic entries, then the server messages.
List<Chat> mergeInboxThread(List<Chat> current, List<Chat> serverNewestFirst) {
  final serverIds = serverNewestFirst.map((c) => c.id).whereType<int>().toSet();
  final newest = _newestId(serverIds);
  final pending = current
      .where(
        (c) =>
            !serverIds.contains(c.id) &&
            (_isOptimisticChat(c) || (c.id ?? 0) > newest),
      )
      .toList();

  return [...pending, ...serverNewestFirst];
}

/// Group-thread counterpart of [mergeInboxThread].
List<Message> mergeGroupThread(
  List<Message> current,
  List<Message> serverNewestFirst,
) {
  final serverIds = serverNewestFirst.map((m) => m.id).whereType<int>().toSet();
  final newest = _newestId(serverIds);
  final pending = current
      .where(
        (m) =>
            !serverIds.contains(m.id) &&
            (_isOptimisticMessage(m) || (m.id ?? 0) > newest),
      )
      .toList();

  return [...pending, ...serverNewestFirst];
}

/// Whether a group-inbox [pagination] block denotes cursor mode (messages
/// already newest-first, the display order) rather than full-thread mode
/// (oldest-first, which must be reversed before display).
///
/// The backend sends `has_more` in BOTH modes (it's additive), so presence of
/// `has_more` alone does NOT mean cursor — that mistake makes a full-thread
/// response (oldest-first) render un-reversed, pushing the newest message off
/// the top of the reversed list so a just-sent message looks like it vanished.
/// The reliable signal: cursor responses omit the full-thread `per_page` key,
/// full mode includes it, and an ancient backend sends no pagination at all —
/// the latter two are oldest-first and must be reversed.
bool isCursorGroupResponse(Pagination? pagination) =>
    pagination != null &&
    pagination.perPage == null &&
    pagination.hasMore != null;

/// Appends an older page ([olderNewestFirst]) to a newest-first group list,
/// for scroll-to-load-older lazy paging.
///
/// The list is newest-first (index 0 = newest), so older messages go at the
/// end. Messages already present (by id) are dropped, so a page that overlaps
/// the current tail never duplicates a row.
///
/// @param  current           The current list (newest-first).
/// @param  olderNewestFirst  The freshly fetched older page (newest-first).
/// @return  [current] followed by the older messages not already present.
List<Message> appendOlderGroupThread(
  List<Message> current,
  List<Message> olderNewestFirst,
) {
  final existing = current.map((m) => m.id).whereType<int>().toSet();
  return [
    ...current,
    ...olderNewestFirst.where((m) => !existing.contains(m.id)),
  ];
}

/// 1:1 counterpart of [isCursorGroupResponse]: whether an inbox [pagination]
/// block denotes cursor mode (newest-first) rather than full-thread mode
/// (oldest-first, reversed before display). Same signal — cursor omits the
/// full-thread `per_page` key while still carrying `has_more`.
bool isCursorInboxResponse(inbox.Pagination? pagination) =>
    pagination != null &&
    pagination.perPage == null &&
    pagination.hasMore != null;

/// 1:1 counterpart of [appendOlderGroupThread]: appends an older page
/// ([olderNewestFirst]) to a newest-first [Chat] list for scroll-to-load-older,
/// dropping any id already present so an overlapping page never duplicates.
List<Chat> appendOlderInboxThread(
  List<Chat> current,
  List<Chat> olderNewestFirst,
) {
  final existing = current.map((c) => c.id).whereType<int>().toSet();
  return [
    ...current,
    ...olderNewestFirst.where((c) => !existing.contains(c.id)),
  ];
}
