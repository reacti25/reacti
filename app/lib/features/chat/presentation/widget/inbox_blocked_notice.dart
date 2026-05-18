import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';
import '../../../../gen/colors.gen.dart';

/// The notice shown in `InboxScreen` when the peer has blocked the current
/// user, replacing the composer to explain why messages cannot be sent.
///
/// Purely presentational — extracted verbatim from `InboxScreen`'s
/// `amIBlockedWidget` helper.
class InboxBlockedNotice extends StatelessWidget {
  /// Creates the "you have been blocked" notice.
  const InboxBlockedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
      width: double.maxFinite,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cFFFFFF.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(44.r),
      ),
      child: Text(
        "You can not send any message to this user. You have been blocked.",
        style: TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
          fontWeight: FontWeight.w300,
          color: AppColors.cFFFFFF.withValues(alpha: 0.6),
          fontSize: 12.sp,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
