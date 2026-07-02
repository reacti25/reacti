import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';
import '../../../../theme/app_theme.dart';

/// A single labelled tap target shown as a row in [MediaPickerSheet].
class MediaPickerOption {
  /// Creates an option with a visible [label] and its [onTap] handler.
  const MediaPickerOption(this.label, this.onTap);

  /// The row's visible text.
  final String label;

  /// Invoked when the row is tapped.
  final VoidCallback onTap;
}

/// A bottom-sheet body listing media-attachment [options] as tappable rows.
///
/// Shown via `showModalBottomSheet` from both `InboxScreen` and
/// `GroupInboxScreen` (through `MediaPickerMixin`). The same widget renders the
/// top-level Gallery/Camera choice and the camera's inline Photo/Video choice,
/// so it stays free of picker/navigation logic — the caller supplies handlers
/// that dismiss the sheet and invoke the matching `ImagePicker` flow.
class MediaPickerSheet extends StatelessWidget {
  /// Creates the media-picker sheet body from [options], shown top-to-bottom.
  const MediaPickerSheet({super.key, required this.options});

  /// The rows to display, in order.
  final List<MediaPickerOption> options;

  /// Builds a single labelled, tappable row of the sheet.
  Widget _option(BuildContext context, MediaPickerOption option) {
    return GestureDetector(
      onTap: option.onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        option.label,
        style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
          color: context.reacti.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 26.h),
      decoration: BoxDecoration(
        // Light: a white sheet with dark labels; dark: the original slab.
        color: isDark ? const Color(0xFF242424) : context.reacti.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 14.h,
        children: options.map((o) => _option(context, o)).toList(),
      ),
    );
  }
}
