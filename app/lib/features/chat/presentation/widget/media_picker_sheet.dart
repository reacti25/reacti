import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';
import '../../../../theme/app_theme.dart';

/// A single media-attachment choice: a labelled, circular icon button.
class MediaPickerOption {
  /// Creates an option with an [icon], a visible [label] and its [onTap].
  const MediaPickerOption(this.label, this.onTap, {required this.icon});

  /// Glyph shown inside the option's circle.
  final IconData icon;

  /// The option's visible text, under the circle.
  final String label;

  /// Invoked when the option is tapped.
  final VoidCallback onTap;
}

/// A bottom sheet presenting media-attachment [options] as WhatsApp-style
/// circular icon buttons with labels.
///
/// Shown via `showModalBottomSheet` from both `InboxScreen` and
/// `GroupInboxScreen` (through `MediaPickerMixin`). The same widget renders the
/// top-level Gallery/Camera choice and the camera's inline Photo/Video choice,
/// so it stays free of picker/navigation logic — the caller supplies handlers
/// that dismiss the sheet and invoke the matching `ImagePicker` flow.
class MediaPickerSheet extends StatelessWidget {
  /// Creates the media-picker sheet body from [options], left-to-right.
  const MediaPickerSheet({super.key, required this.options});

  /// The options to display, in order.
  final List<MediaPickerOption> options;

  /// Builds one option: a lime circle with the icon, and the label beneath.
  Widget _option(BuildContext context, MediaPickerOption option) {
    final reacti = context.reacti;
    return GestureDetector(
      onTap: option.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 76.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reacti.brandFill,
              ),
              child: Icon(option.icon, color: reacti.onBrandFill, size: 28.w),
            ),
            SizedBox(height: 8.h),
            Text(
              option.label,
              textAlign: TextAlign.center,
              style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
                fontSize: 13.sp,
                color: reacti.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 40.h),
      decoration: BoxDecoration(
        // Light: a white sheet with dark labels; dark: the original slab.
        color: isDark ? const Color(0xFF242424) : context.reacti.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      child: Wrap(
        spacing: 28.w,
        runSpacing: 20.h,
        children: options.map((o) => _option(context, o)).toList(),
      ),
    );
  }
}
