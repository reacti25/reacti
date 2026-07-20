import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';

/// Bottom-sheet body showing a single message's timing details.
///
/// Phase 1 shows the human-readable sent time and, for the current user's own
/// messages, a delivery-status label (Sent / Delivered / Seen). Exact
/// delivered/seen timestamps arrive in a later phase once the backend stores
/// them; this widget stays presentational so that upgrade is additive.
class MessageDetailsSheet extends StatelessWidget {
  /// Creates the details sheet.
  ///
  /// [sentAt] is the human-readable send time (e.g. "2 mins ago").
  /// [statusLabel] is the delivery status for an own message, or null for a
  /// received message (which has no outgoing status to show).
  const MessageDetailsSheet({
    super.key,
    required this.sentAt,
    this.statusLabel,
    this.seenAt,
  });

  /// Human-readable time the message was sent.
  final String sentAt;

  /// Delivery status for an own message; null hides the status row.
  final String? statusLabel;

  /// Exact formatted time the message was seen, or null if unread / unknown.
  final String? seenAt;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Message info",
              style: TextFontStyle.headline16w500C333333Poppins.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.h),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: "Sent",
              value: sentAt,
            ),
            if (statusLabel != null) ...[
              SizedBox(height: 12.h),
              _DetailRow(
                icon: Icons.done_all_rounded,
                label: "Status",
                value: statusLabel!,
              ),
            ],
            if (seenAt != null) ...[
              SizedBox(height: 12.h),
              _DetailRow(
                icon: Icons.visibility_outlined,
                label: "Seen",
                value: seenAt!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A labelled icon + value row inside [MessageDetailsSheet].
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: onSurface.withValues(alpha: 0.7)),
        SizedBox(width: 12.w),
        Text(
          "$label: ",
          style: TextFontStyle.headline14w600C333333Poppins.copyWith(
            color: onSurface.withValues(alpha: 0.7),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextFontStyle.headline14w600C333333Poppins.copyWith(
              color: onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
