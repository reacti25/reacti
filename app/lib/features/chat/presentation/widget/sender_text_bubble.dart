import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';
import '../../../../helpers/ui_helpers.dart';

/// The text portion of an outgoing (sent) chat bubble.
///
/// Renders [message] in the app's primary-colour bubble with a [time]
/// stamp beneath it, followed by a sent indicator: a small spinner while
/// the message is still uploading ([isLocal] true) or a check mark once
/// it is delivered. Extracted from `SenderMessageWidget` so the bubble's
/// presentation can be unit-tested in isolation.
class SenderTextBubble extends StatelessWidget {
  /// Creates the sent-message text bubble.
  ///
  /// [message] is the text body, [time] the human-readable timestamp, and
  /// [isLocal] whether the message is still an optimistic, in-flight entry
  /// (which shows a spinner instead of the delivered check mark).
  const SenderTextBubble({
    super.key,
    required this.message,
    required this.isLocal,
    this.time,
  });

  /// Text body of the sent message.
  final String message;

  /// Human-readable timestamp shown beneath the message.
  final String? time;

  /// Whether the message is an optimistic local entry still being uploaded.
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 3.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.allPrimaryColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8.r),
            bottomLeft: Radius.circular(8.r),
            topRight: Radius.circular(8.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextFontStyle.headline14w600C333333Poppins.copyWith(
                fontSize: 12.5.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time ?? "",
                  style: TextFontStyle.headline14w600C333333Poppins.copyWith(
                    fontSize: 10.sp,
                    color: Colors.black,
                  ),
                ),
                UIHelper.horizontalSpace(4.w),
                isLocal
                    ? SizedBox(
                      height: 8.sp,
                      width: 8.sp,
                      child: CircularProgressIndicator(
                        color: AppColors.c000000,
                        strokeWidth: 1.5.w,
                      ),
                    )
                    : Icon(
                      Icons.check_rounded,
                      size: 12.sp,
                      color: Colors.blueAccent,
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
