import '../model/group_inbox_response.dart';

/// One row of the group thread list: a message, plus the reactions that
/// answer it when it is a media original.
///
/// The group thread stores every message flat and newest-first; reactions
/// are ordinary messages of type `reaction` whose `replyTo.id` names the
/// media they answer. Rendering them inline interleaves reactions to
/// different media, so the screen folds each reaction under its original
/// (one framed cluster per media) and this is the shape it renders from.
class GroupThreadRow {
  /// Creates a row for [message] with its [reactions] (oldest-first).
  const GroupThreadRow(this.message, [this.reactions = const []]);

  /// The message rendered as the row's bubble (the original, for a cluster).
  final Message message;

  /// Reactions answering [message], oldest-first so they read top to bottom.
  final List<Message> reactions;
}

/// Folds reactions under their originals.
///
/// [newestFirst] is the screen's list (index 0 = newest). A reaction whose
/// original is in the list is removed from its own chronological slot and
/// attached to the original's row, so the cluster sits where the media was
/// sent and later reactions join it there. A reaction whose original is not
/// loaded (older page, or a deleted original) stays a plain row where it is.
///
/// ponytail: rebuilt on every frame of the screen (O(n) over the loaded
/// page); memoise on the list identity if a thread ever gets slow.
List<GroupThreadRow> buildGroupThreadRows(List<Message> newestFirst) {
  final ids = newestFirst.map((m) => m.id).whereType<int>().toSet();
  final reactionsOf = <int, List<Message>>{};
  final rows = <Message>[];

  for (final m in newestFirst) {
    final originalId = m.messageType == 'reaction' ? m.replyTo?.id : null;
    if (originalId != null && originalId != m.id && ids.contains(originalId)) {
      (reactionsOf[originalId] ??= []).add(m);
      continue;
    }
    rows.add(m);
  }

  return [
    for (final m in rows)
      GroupThreadRow(
        m,
        // Collected newest-first; show oldest-first under the original.
        (reactionsOf[m.id] ?? const []).reversed.toList(growable: false),
      ),
  ];
}
