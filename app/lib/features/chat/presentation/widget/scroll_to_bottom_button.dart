import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../gen/colors.gen.dart';

/// The floating "scroll to newest message" button shown above the composer.
///
/// Used as the `floatingActionButton` of both `InboxScreen` and
/// `GroupInboxScreen` once the message list is scrolled away from the
/// bottom. The screens keep the visibility decision (`_showScrollToBottom`)
/// and only mount this widget while it should be visible; tapping it
/// invokes [onPressed] to animate the list back to the newest message.
class ScrollToBottomButton extends StatelessWidget {
  /// Creates the scroll-to-bottom button.
  ///
  /// [onPressed] animates the message list back to the newest message.
  const ScrollToBottomButton({super.key, required this.onPressed});

  /// Invoked when the button is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 70.h),
      child: FloatingActionButton.small(
        onPressed: onPressed,
        backgroundColor: AppColors.allPrimaryColor,
        child: const Icon(Icons.arrow_downward, color: Colors.black),
      ),
    );
  }
}
