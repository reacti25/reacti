import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';
import '../../../../theme/app_theme.dart';
import 'one_time_notice.dart';

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
  const MediaPickerSheet({super.key, required this.options, this.oneTime});

  /// When set, the sheet also offers the "One-time" switch bound to this
  /// value. Null (groups) hides it.
  final ValueNotifier<bool>? oneTime;

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

  /// The switch that makes the next photo or video one-time. It sits on the
  /// sheet because every way of attaching media (gallery, camera) starts here.
  Widget _oneTimeSwitch(BuildContext context, ValueNotifier<bool> armed) {
    final reacti = context.reacti;
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      // Its own Material: the sheet's coloured box would otherwise hide the
      // tile's ink (Flutter asserts on that).
      child: Material(
        type: MaterialType.transparency,
        child: ValueListenableBuilder<bool>(
          valueListenable: armed,
          builder:
              (context, on, _) => SwitchListTile.adaptive(
                key: const Key('one-time-switch'),
                contentPadding: EdgeInsets.zero,
                value: on,
                onChanged: (value) => armed.value = value,
                activeTrackColor: reacti.brandFill,
                secondary: OneTimeBadge(size: 28.w, color: reacti.textPrimary),
                title: Text(
                  'One-time',
                  style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
                    fontSize: 14.sp,
                    color: reacti.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Opens once. Erased for both of you after you watch the '
                  'reaction.',
                  style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
                    fontSize: 11.sp,
                    color: reacti.textSecondary,
                  ),
                ),
              ),
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
      // Scrollable: a bottom sheet is capped at 9/16 of the screen, and with
      // the switch the content can be taller than that on a short phone.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 28.w,
              runSpacing: 20.h,
              children: options.map((o) => _option(context, o)).toList(),
            ),
            if (oneTime != null) _oneTimeSwitch(context, oneTime!),
          ],
        ),
      ),
    );
  }
}
