import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';
import '../../../../theme/app_theme.dart';

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
    this.isEdited = false,
  });

  /// Whether the sender has edited this message (shows an "edited" label).
  final bool isEdited;

  /// Text body of the received message.
  final String message;

  /// Human-readable timestamp shown beneath the message.
  final String? time;

  /// Whether this text is a caption sitting under media (drives the gap above
  /// it). The media renders first, so the spacing belongs on top.
  final bool hasFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: hasFile ? 10.h : 0),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: context.reacti.bubbleIn,
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
              color: context.reacti.onBubbleIn,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEdited) ...[
                Text(
                  "edited",
                  style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
                    fontSize: 9.sp,
                    fontStyle: FontStyle.italic,
                    color: context.reacti.onBubbleIn.withValues(alpha: 0.5),
                  ),
                ),
                SizedBox(width: 4.w),
              ],
              Text(
                time ?? "",
                style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
                  fontSize: 10.sp,
                  color: context.reacti.onBubbleIn.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
