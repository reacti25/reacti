// Shared instrumentation for media-seal integrity — emitted once per received
// media message from the chat list sites (InboxScreen + GroupInboxScreen) so
// the 1:1 and group paths share one code path and dedup is natural.

import 'package:flutter/foundation.dart';

import 'analytics_locator.dart';
import 'events.dart';

/// Message ids already reported via [trackMediaReceivedSealState].
///
/// `itemBuilder` re-runs for the same message on every list rebuild/scroll, so
/// without this guard a single message would emit repeatedly. In-memory and
/// per-launch — one event per message per app session is the intended grain.
final Set<int> _reportedSealStateIds = <int>{};

/// Clears the dedup set. Test-only, so each test starts from a clean slate.
@visibleForTesting
void resetMediaSealStateDedupForTest() => _reportedSealStateIds.clear();

/// Emits [Events.mediaReceivedSealState] once per received media message,
/// recording whether the media arrived **sealed** (would render the blur
/// placeholder) or **open** (rendered unblurred).
///
/// Call from the chat list site for every received message; text messages are
/// skipped. The emit is fire-and-forget and fully guarded — analytics must
/// never break rendering.
///
/// [messageId] dedups across rebuilds (required; a null id is skipped).
/// [mediaType] is the raw `media_type` as received (may be null/unexpected).
/// [messageType] is the server message kind (`reaction` etc.), used to mirror
/// the bubble's seal condition. [sealed] is `isMediaSealed(data.isBlurred)` —
/// the same value the bubble seeds its blur from. [scope] is `private`|`group`.
/// [file] is the attachment URL; when empty the message has no media and is
/// skipped (no text-message noise).
void trackMediaReceivedSealState({
  required int? messageId,
  required String? mediaType,
  required String? messageType,
  required bool sealed,
  required String scope,
  required String? file,
}) {
  try {
    // Only media messages — text bubbles carry no file.
    if (file == null || file.isEmpty) return;
    if (messageId == null) return; // can't dedup without a stable id
    if (!_reportedSealStateIds.add(messageId)) return; // already reported

    // Mirror the receiver bubble's blur-placeholder condition: it seals only
    // when the type is one it recognises. A media file with an unexpected
    // media_type therefore renders OPEN even when is_blurred is true — exactly
    // the case media_type_raw is here to surface.
    final isSealableType =
        mediaType == 'image' ||
        mediaType == 'video' ||
        mediaType == 'reaction' ||
        messageType == 'reaction';
    final sealState = (sealed && isSealableType) ? 'sealed' : 'open';

    analytics.track(Events.mediaReceivedSealState, {
      Props.sealState: sealState,
      // media_kind mirrors the existing convention: images are 'image',
      // everything else (incl. unknown) buckets as 'video'.
      Props.mediaKind: mediaType == 'image' ? 'image' : 'video',
      Props.scope: scope,
      // null media_type would be dropped by track(); a sentinel keeps it
      // visible so Branch C can see how often it actually happens.
      Props.mediaTypeRaw: mediaType ?? '(null)',
    });
  } catch (_) {
    // Analytics must never disrupt rendering.
  }
}
