import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';
import '../../../../theme/app_theme.dart';

/// The "1" in a circle that marks one-time media, as in other messaging apps.
class OneTimeBadge extends StatelessWidget {
  /// Creates the badge; [size] is its diameter and [color] its ink.
  const OneTimeBadge({super.key, this.size, this.color});

  /// Diameter; defaults to 18 logical pixels (scaled).
  final double? size;

  /// Ring and digit colour; defaults to the theme's secondary text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final d = size ?? 18.w;
    final ink = color ?? context.reacti.textSecondary;
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ink, width: 1.5),
      ),
      child: Text(
        '1',
        style: TextStyle(
          color: ink,
          fontSize: d * 0.6,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The tile shown in place of one-time media that this person may not (or may
/// no longer) see: the sender's own one-timer, the reaction they recorded, or
/// media they already opened once.
///
/// It never loads the file, so nothing is fetched or cached for it.
class OneTimeNotice extends StatelessWidget {
  /// Creates the tile with its one-line [label], e.g. "One-time photo".
  const OneTimeNotice({super.key, required this.label});

  /// What the tile stands for, e.g. "Opened".
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? null : context.reacti.card,
        border: Border.all(
          color: isDark ? Colors.white30 : context.reacti.hairline,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OneTimeBadge(),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              label,
              style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
                fontSize: 12.sp,
                color: isDark ? Colors.white70 : context.reacti.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The label for a one-time [mediaType] (`image`, `video`, anything else).
String oneTimeLabel(String? mediaType) => switch (mediaType) {
  'image' => 'One-time photo',
  'video' => 'One-time video',
  _ => 'One-time media',
};
