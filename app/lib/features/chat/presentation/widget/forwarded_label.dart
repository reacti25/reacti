import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';

/// Small muted "Forwarded" indicator shown above a forwarded message's content
/// (WhatsApp-style), used by both the sender and receiver bubbles for text and
/// media alike.
class ForwardedLabel extends StatelessWidget {
  /// Creates the label; [color] tints the icon and text to match the bubble.
  const ForwardedLabel({super.key, required this.color});

  /// Icon + text colour (typically a muted on-bubble colour).
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply_rounded, size: 12.sp, color: color),
          SizedBox(width: 3.w),
          Text(
            "Forwarded",
            style: TextFontStyle.headline14w600C333333Poppins.copyWith(
              fontSize: 10.sp,
              fontStyle: FontStyle.italic,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
