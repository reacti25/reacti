import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The three delivery states shown beside an outgoing text message.
enum MessageTickStatus { sending, sent, seen }

/// Maps raw message flags to a [MessageTickStatus].
///
/// An in-flight optimistic message ([isLocal]) is [MessageTickStatus.sending].
/// Otherwise it is [MessageTickStatus.seen] only when the recipient has seen it
/// AND the local user keeps read receipts on — receipts are reciprocal, so a
/// user who turns them off stops seeing others' seen state too. Everything else
/// is [MessageTickStatus.sent].
MessageTickStatus tickStatusFor({
  required bool isLocal,
  required bool isSeen,
  required bool readReceiptsEnabled,
}) {
  if (isLocal) return MessageTickStatus.sending;
  if (isSeen && readReceiptsEnabled) return MessageTickStatus.seen;
  return MessageTickStatus.sent;
}

/// Sent-message status indicator: spinner (sending) → one check (sent) → two
/// checks (seen).
///
/// Centralised so the text-bubble call sites render the three states
/// identically and the widget can be unit-tested in isolation. Media bubbles
/// deliberately show no tick (the reaction itself is the "seen" proof), and
/// reaction bubbles use a separate grey→green dot.
class MessageStatusTicks extends StatelessWidget {
  /// Creates the status indicator for the given [status].
  const MessageStatusTicks({
    super.key,
    required this.status,
    this.checkColor,
    this.spinnerColor,
    this.size,
  });

  /// Which of the three states to render.
  final MessageTickStatus status;

  /// Colour of the check mark(s); defaults to the app's sent/seen blue.
  final Color? checkColor;

  /// Colour of the in-flight spinner; defaults to [checkColor].
  final Color? spinnerColor;

  /// Icon / spinner size in sp; defaults to 12.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tint = checkColor ?? Colors.blueAccent;
    final s = (size ?? 12).sp;

    switch (status) {
      case MessageTickStatus.sending:
        return SizedBox(
          height: s * 0.7,
          width: s * 0.7,
          child: CircularProgressIndicator(
            color: spinnerColor ?? tint,
            strokeWidth: 1.5.w,
          ),
        );
      case MessageTickStatus.sent:
        return Icon(Icons.check_rounded, size: s, color: tint);
      case MessageTickStatus.seen:
        // Two checks for "seen", tinted consistently with the single check.
        return Icon(Icons.done_all, size: s, color: tint);
    }
  }
}

/// Small status dot for an outgoing reaction: grey until the recipient has
/// watched it, then [AppColors.allPrimaryColor] green.
///
/// Reactions are the app's only "did they see my reaction" signal, so the dot
/// is intentionally quiet. Honours the reciprocal read-receipts setting:
/// [seen] is only passed `true` when the local user keeps receipts on.
class ReactionSeenDot extends StatelessWidget {
  /// Creates the reaction status dot.
  const ReactionSeenDot({super.key, required this.seen, this.size});

  /// Whether the recipient has watched the reaction (and receipts are on).
  final bool seen;

  /// Diameter in sp; defaults to 8.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final d = (size ?? 8).sp;
    return Container(
      height: d,
      width: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: seen ? AppColors.allPrimaryColor : Colors.white38,
      ),
    );
  }
}
