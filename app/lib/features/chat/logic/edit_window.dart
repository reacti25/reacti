/// How long after sending a message it may still be edited. Mirrors the
/// backend rule ("within 10 minutes of sending it"); the server remains
/// authoritative — this only decides whether the client shows the Edit option.
const Duration kEditWindow = Duration(minutes: 10);

/// Whether a message sent at [sentAtUtc] can still be edited at [nowUtc].
///
/// Returns false when [sentAtUtc] is null (unknown send time — e.g. an
/// optimistic local echo or a pre-upgrade message) so the option is hidden
/// rather than shown-then-rejected. A slightly-future [sentAtUtc] (clock skew)
/// is treated as editable.
bool canEditMessageAt(DateTime? sentAtUtc, DateTime nowUtc) {
  if (sentAtUtc == null) return false;
  return nowUtc.difference(sentAtUtc) < kEditWindow;
}
