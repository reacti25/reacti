import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';

/// The text portion of an incoming (received) chat bubble.
///
/// Renders [message] in the dark received-message bubble with a [time]
/// stamp beneath it. [hasFile] reflects whether media follows below the
/// text — it drives the bottom margin so the text sits snug against the
/// media when present. Extracted from `ReceiverMessageWidget` so the
/// bubble's presentation can be unit-tested in isolation.
class ReceiverTextBubble extends StatelessWidget {
  /// Creates the received-message text bubble.
  ///
  /// [message] is the text body, [time] the human-readable timestamp, and
  /// [hasFile] whether the bubble also carries a media attachment below.
  const ReceiverTextBubble({
    super.key,
    required this.message,
    required this.hasFile,
    this.time,
  });

  /// Text body of the received message.
  final String message;

  /// Human-readable timestamp shown beneath the message.
  final String? time;

  /// Whether the bubble also has media below it (drives the bottom margin).
  final bool hasFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: hasFile ? 10.h : 0),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E0A),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8.r),
          bottomRight: Radius.circular(8.r),
          topLeft: Radius.circular(8.r),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
              fontSize: 12.5.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            time ?? "",
            style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
              fontSize: 10.sp,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
