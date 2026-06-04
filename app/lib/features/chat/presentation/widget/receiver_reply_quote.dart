import 'dart:ui';

import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common_widget/inbox_custom_network_image.dart';
import '../../../../constants/text_font_style.dart';

/// The quoted-reply preview shown above an incoming chat bubble.
///
/// When the received message is itself a reply, this renders the
/// original message's sender name, text, and an optional (possibly
/// blurred) media thumbnail. Tapping it invokes [onTapReply] with the
/// quoted message's id so the parent can scroll to the original.
///
/// Extracted from `ReceiverMessageWidget` so the quoted-reply
/// presentation can be unit-tested in isolation. The parent only builds
/// this when the reply is non-null.
class ReceiverReplyQuote extends StatelessWidget {
  /// Creates the quoted-reply preview.
  ///
  /// [replyTo] is the quoted message (loosely typed to tolerate API
  /// variation); [onTapReply] is invoked with its id when the preview is
  /// tapped.
  const ReceiverReplyQuote({super.key, required this.replyTo, this.onTapReply});

  /// The quoted message this bubble replies to; loosely typed.
  final dynamic replyTo;

  /// Invoked with a message id when the quoted-reply preview is tapped.
  final Function(int)? onTapReply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: GestureDetector(
        onTap: () {
          if (replyTo?.id != null) {
            onTapReply?.call(replyTo!.id!);
          }
        },
        child: Container(
          padding: EdgeInsets.all(8.sp),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border(
              left: BorderSide(color: AppColors.allPrimaryColor, width: 3.w),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                replyTo?.sender?.firstName ?? "",
                style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.allPrimaryColor,
                  fontSize: 11.sp,
                ),
              ),
              if (replyTo?.text != null && replyTo!.text!.isNotEmpty)
                Text(
                  replyTo!.text!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
                    fontSize: 10.sp,
                    color: Colors.white70,
                  ),
                ),
              if (replyTo?.file != null && replyTo!.file!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 40.h),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          (replyTo!.isBlurred == 1 ||
                                  replyTo!.isBlurred == true ||
                                  replyTo!.isBlurred == '1' ||
                                  replyTo!.isBlurred == 'true')
                              ? ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: InboxCustomNetworkImage(
                                  urls: replyTo!.file!,
                                  fit: BoxFit.cover,
                                ),
                              )
                              : InboxCustomNetworkImage(
                                urls: replyTo!.file!,
                                fit: BoxFit.cover,
                              ),
                          if (replyTo!.mediaType == 'video')
                            Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 24.sp,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
