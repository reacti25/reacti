import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';

/// The bottom-sheet body confirming deletion of a single chat message.
///
/// Shown via `showModalBottomSheet` from `InboxScreen` on a message
/// long-press. A single tappable row; tapping it invokes [onConfirm],
/// which performs the delete API call, drops the row and dismisses the
/// sheet — that logic stays in the screen so this widget is purely
/// presentational.
class DeleteMessageSheet extends StatelessWidget {
  /// Creates the delete-message confirmation sheet.
  ///
  /// [onConfirm] deletes the message and dismisses the sheet.
  const DeleteMessageSheet({super.key, required this.onConfirm});

  /// Invoked when the "Delete this message" row is tapped.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: InkWell(
        onTap: onConfirm,
        child: Row(
          spacing: 12.w,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, size: 20.sp),
            Text(
              "Delete this message",
              // Was pinned to black — invisible on the themed dark sheet in
              // dark mode; onSurface reads in both (white in dark, near-black
              // in light).
              style: TextFontStyle.headline16w500C333333Poppins.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
