import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';
import '../../../../helpers/ui_helpers.dart';

/// The "Replying to …" banner shown above the message composer while the
/// user is staging a reply.
///
/// Renders a thin divider, a `Replying to: <chatName>` header, and a
/// preview line — the quoted [replyMessage] text, or a
/// `Replying to <media>` label when replying to media — plus a close
/// button that invokes [onClose] to cancel the staged reply.
///
/// Extracted from `InboxScreen` and `GroupInboxScreen`, which carried
/// byte-identical inline copies of this banner.
class ChatReplyBanner extends StatelessWidget {
  /// Creates the reply banner.
  ///
  /// [chatName] is the conversation name shown in the header.
  /// [replyMessage] is the quoted text when replying to a text message;
  /// [replyImage] is non-null when replying to media and [replyMediaType]
  /// labels that media. [onClose] cancels the staged reply.
  const ChatReplyBanner({
    super.key,
    required this.chatName,
    required this.onClose,
    this.replyMessage,
    this.replyImage,
    this.replyMediaType,
  });

  /// Name of the conversation being replied within.
  final String chatName;

  /// The quoted message text, when replying to a text message.
  final String? replyMessage;

  /// Non-null when the reply targets a media message.
  final String? replyImage;

  /// Media kind label used when [replyImage] is set (defaults to `image`).
  final String? replyMediaType;

  /// Invoked when the close button is tapped to cancel the staged reply.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: AppColors.cFFFFFF.withValues(alpha: 0.4),
          width: double.maxFinite,
          height: 0.5.h,
        ),
        UIHelper.verticalSpace(8.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replying to: $chatName',
                      style: TextFontStyle.headline14w500CFFFFFFPoppins
                          .copyWith(
                            fontSize: 13.5.sp,
                            color: AppColors.cFFFFFF.withValues(alpha: 0.9),
                          ),
                    ),
                    UIHelper.verticalSpace(2.h),
                    // Show text reply if exists
                    if (replyMessage != null)
                      Text(
                        replyMessage!,
                        style: TextFontStyle.headline14w400C666666Poppins
                            .copyWith(
                              color: AppColors.cFFFFFF,
                              fontSize: 13.sp,
                            ),
                      ),
                    // Show image reply if exists
                    if (replyImage != null)
                      Text(
                        'Replying to ${replyMediaType ?? 'image'}',
                        style: TextFontStyle.headline14w400C666666Poppins
                            .copyWith(
                              color: AppColors.cFFFFFF,
                              fontSize: 13.sp,
                            ),
                      ),
                  ],
                ),
              ),
              InkWell(
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  color: AppColors.cFFFFFF.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
