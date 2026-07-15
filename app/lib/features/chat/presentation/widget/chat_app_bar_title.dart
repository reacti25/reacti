import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common_widget/custom_network_image.dart';
import '../../../../common_widget/group_avatar.dart';
import '../../../../constants/text_font_style.dart';
import '../../../../theme/app_theme.dart';

/// The conversation app-bar title: a circular avatar beside the chat name.
///
/// Used as the `AppBar.title` of both `InboxScreen` and `GroupInboxScreen`,
/// which carried a byte-identical inline copy. `GroupInboxScreen` still
/// wraps this in its own `GestureDetector` to open the group details, so
/// this widget stays purely presentational and carries no tap behaviour.
class ChatAppBarTitle extends StatelessWidget {
  /// Creates the app-bar title.
  ///
  /// [name] is the conversation/group name; [imageUrl] is the avatar URL.
  const ChatAppBarTitle({
    super.key,
    required this.name,
    required this.imageUrl,
    this.isGroup = false,
    this.onAvatarTap,
  });

  /// Display name shown next to the avatar.
  final String name;

  /// Avatar image URL loaded into the leading circle.
  final String imageUrl;

  /// Whether this is a group conversation — a group with no image shows the
  /// people-icon fallback (matching the chat list), rather than a blank circle.
  final bool isGroup;

  /// Optional tap handler for the avatar (e.g. enlarge the photo). When null
  /// the avatar is non-interactive, so the group screen's own wrapping tap
  /// (which opens group details) is preserved.
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final avatar =
        isGroup
            ? GroupAvatar(url: imageUrl, size: 36.w)
            : ClipOval(
              child: CustomNetworkImage(
                width: 36.w,
                height: 36.h,
                urls: imageUrl,
              ),
            );
    return Row(
      spacing: 14.w,
      children: [
        onAvatarTap == null
            ? avatar
            : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAvatarTap,
              child: avatar,
            ),
        Text(
          name,
          style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
            color: context.reacti.textPrimary,
          ),
        ),
      ],
    );
  }
}
