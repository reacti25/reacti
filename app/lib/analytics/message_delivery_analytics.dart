// Shared instrumentation for realtime message delivery — emitted from the
// recipient-side Pusher onEvent (InboxScreen + GroupInboxScreen). Joined with
// the backend's message_persisted event, this is what lets us detect a message
// that was persisted on the server but never delivered over Pusher.

import 'analytics_locator.dart';
import 'events.dart';

/// Emits [Events.messageReceived] when a realtime message lands on the
/// recipient over Pusher. Fire-and-forget — must never disrupt rendering.
///
/// [scope] is `private`|`group`; [messageType] is the catalog kind
/// (`text`|`media`|`reaction`). `delivery_ms` is intentionally omitted: the
/// realtime payload carries only a relative `humanize_date`, so there is no
/// reliable send timestamp to measure latency against — better absent than
/// fabricated.
void trackMessageReceived({
  required String scope,
  required String messageType,
}) {
  try {
    analytics.track(Events.messageReceived, {
      Props.scope: scope,
      Props.messageType: messageType,
    });
  } catch (_) {
    // Analytics must never disrupt rendering.
  }
}

/// Maps a realtime payload's raw `message_type` and `file` to the catalog
/// `message_type` enum: `reaction` when the server typed it so, else `media`
/// when a file is attached, else `text`.
String messageTypeFromRealtime({String? rawType, Object? file}) {
  if (rawType == 'reaction') return 'reaction';
  return file != null ? 'media' : 'text';
}
