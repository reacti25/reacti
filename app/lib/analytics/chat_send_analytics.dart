import 'dart:async';

import 'package:camera/camera.dart' show XFile;

import 'activation_funnel.dart';

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
/// On failure, [error] (the thrown send error) is mapped to a coarse
/// `failure_reason` so timeouts/4xx/5xx/network drops are distinguishable.
void trackMessageSend({
  required String scope,
  String? type,
  XFile? file,
  required int ms,
  required bool success,
  Object? error,
}) {
  try {
    final result = success ? 'success' : 'failure';
    final failureReason = success ? null : failureReasonFromError(error);
    if (type == 'reaction') {
      analytics.track(Events.reactionSent, {
        Props.scope: scope,
        Props.uploadMs: ms,
        Props.result: result,
        if (failureReason != null) Props.failureReason: failureReason,
      });
    } else {
      analytics.track(Events.messageSent, {
        Props.messageType: file != null ? 'media' : 'text',
        Props.scope: scope,
        Props.sendMs: ms,
        Props.result: result,
        if (failureReason != null) Props.failureReason: failureReason,
      });
      // The activation moment, and the one the whole walkthrough is aimed at.
      // Only a SUCCESSFUL send counts: a failed attempt is not a first
      // message, and letting it through would make activation look healthier
      // than it is at precisely the point where a bug would be hiding.
      if (success) {
        unawaited(
          ActivationFunnel.reach(
            Events.firstMessageSent,
            extra: {
              Props.messageType: file != null ? 'media' : 'text',
              Props.scope: scope,
            },
          ),
        );
      }
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
