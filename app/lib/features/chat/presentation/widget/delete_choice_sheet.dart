import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';

/// Bottom-sheet offering the delete options for a message (WhatsApp-style):
/// "Delete for me" always, and "Delete for everyone" only when the caller may
/// (their own 1:1 message). Purely presentational — the screen performs the
/// API calls via the [onDeleteForMe] / [onDeleteForEveryone] callbacks.
class DeleteChoiceSheet extends StatelessWidget {
  /// Creates the delete-choice sheet.
  ///
  /// [onDeleteForMe] hides the message for the current user only.
  /// [onDeleteForEveryone] removes it for everyone; pass null to hide that row
  /// (e.g. a received message, or a group message).
  const DeleteChoiceSheet({
    super.key,
    required this.onDeleteForMe,
    this.onDeleteForEveryone,
  });

  /// Invoked to delete the message for the current user only.
  final VoidCallback onDeleteForMe;

  /// Invoked to delete for everyone, or null when not offered.
  final VoidCallback? onDeleteForEveryone;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DeleteRow(
              icon: Icons.delete_outline_rounded,
              label: "Delete for me",
              color: onSurface,
              onTap: onDeleteForMe,
            ),
            if (onDeleteForEveryone != null)
              _DeleteRow(
                icon: Icons.delete_forever_rounded,
                label: "Delete for everyone",
                color: Theme.of(context).colorScheme.error,
                onTap: onDeleteForEveryone!,
              ),
          ],
        ),
      ),
    );
  }
}

/// One tappable delete option row.
class _DeleteRow extends StatelessWidget {
  const _DeleteRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, size: 20.sp, color: color),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                label,
                style: TextFontStyle.headline16w500C333333Poppins.copyWith(
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
