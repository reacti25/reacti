import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common_widget/custom_button.dart';

/// The "Unblock" call-to-action shown in `InboxScreen` when the current
/// user has blocked the peer, replacing the composer.
///
/// Presentational only — extracted from `InboxScreen`'s `_isBlockWidget`
/// helper. The unblock API call and conversation reload stay in the
/// screen, invoked through [onTap].
class UnblockButton extends StatelessWidget {
  /// Creates the unblock button.
  ///
  /// [onTap] performs the unblock and reloads the conversation.
  const UnblockButton({super.key, required this.onTap});

  /// Invoked when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: CustomButton(onTap: onTap, btnName: "Unblock"),
    );
  }
}
