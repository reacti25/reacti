import 'package:camera/camera.dart' show XFile;

import 'analytics_buckets.dart';
import 'analytics_locator.dart';
import 'events.dart';

/// Emits the analytics for a completed message/reaction send (fire-and-forget).
///
/// Shared by the one-to-one ([SendMessageRx]) and group ([SendGroupMessageRx])
/// send paths so the instrumentation lives in one place. It distinguishes a
/// reaction upload (`type == 'reaction'`) from a normal message and, when a file
/// was attached, also emits `media_uploaded`. Never throws and never blocks the
/// caller — the (async) file-size read is detached.
///
/// [scope] is `private` or `group`. [ms] is the measured send/upload duration.
void trackMessageSend({
  required String scope,
  String? type,
  XFile? file,
  required int ms,
  required bool success,
}) {
  try {
    final result = success ? 'success' : 'failure';
    if (type == 'reaction') {
      analytics.track(Events.reactionSent, {
        Props.scope: scope,
        Props.uploadMs: ms,
        Props.result: result,
      });
    } else {
      analytics.track(Events.messageSent, {
        Props.messageType: file != null ? 'media' : 'text',
        Props.scope: scope,
        Props.sendMs: ms,
        Props.result: result,
      });
    }
    if (file != null) _trackMediaUploaded(file, ms, result);
  } catch (_) {
    // Fire-and-forget — analytics must never break a send.
  }
}

/// Emits `media_uploaded` with a coarse size bucket. The size read is async and
/// detached so it never delays the send that just completed.
void _trackMediaUploaded(XFile file, int ms, String result) {
  () async {
    try {
      final bytes = await file.length();
      final kind = mediaKindFromPath(file.path);
      analytics.track(Events.mediaUploaded, {
        Props.uploadMs: ms,
        Props.sizeBucket: sizeBucket(bytes),
        if (kind != null) Props.mediaKind: kind,
        Props.result: result,
      });
    } catch (_) {
      // Fire-and-forget.
    }
  }();
}
