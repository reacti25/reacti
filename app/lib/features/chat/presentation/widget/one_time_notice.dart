import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';
import '../../../../theme/app_theme.dart';

/// The "1" in a circle that marks one-time media, as in other messaging apps.
class OneTimeBadge extends StatelessWidget {
  /// Creates the badge; [size] is its diameter, [color] its ink and [fill]
  /// the colour inside the ring.
  const OneTimeBadge({super.key, this.size, this.color, this.fill});

  /// Diameter; defaults to 18 logical pixels (scaled).
  final double? size;

  /// Ring and digit colour; defaults to the theme's secondary text colour.
  final Color? color;

  /// Colour inside the ring; none by default (an outline only).
  final Color? fill;

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
        color: fill,
        border: Border.all(color: fill ?? ink, width: 1.5),
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

/// The "1" button on a sending screen: tap it to send the media being
/// reviewed as one-time, tap again to send it normally.
///
/// It sits at the end of the caption field on every sending screen (the
/// gallery picker, the Android review screen and the composer holding a
/// camera capture), so the choice is made last, with the media in view.
class OneTimeToggle extends StatelessWidget {
  /// Creates the button bound to [armed]. The colours default to the theme's;
  /// the dark gallery screens pass their own.
  const OneTimeToggle({
    super.key,
    required this.armed,
    this.accent,
    this.onAccent,
    this.idle,
  });

  /// Whether the media goes out as one-time. Flipped by a tap.
  final ValueNotifier<bool> armed;

  /// Fill while on; defaults to the brand fill.
  final Color? accent;

  /// The "1" while on; defaults to the colour that reads on the brand fill.
  final Color? onAccent;

  /// Ring and "1" while off; defaults to the secondary text colour.
  final Color? idle;

  @override
  Widget build(BuildContext context) {
    final reacti = context.reacti;
    return ValueListenableBuilder<bool>(
      valueListenable: armed,
      builder:
          (context, on, _) => IconButton(
            key: const Key('one-time-switch'),
            tooltip: on ? 'One-time is on' : 'Send as one-time',
            isSelected: on,
            onPressed: () => armed.value = !on,
            icon: OneTimeBadge(
              size: 22.w,
              color:
                  on
                      ? onAccent ?? reacti.onBrandFill
                      : idle ?? reacti.textSecondary,
              fill: on ? accent ?? reacti.brandFill : null,
            ),
          ),
    );
  }
}

/// One line saying what one-time means, shown on the dark gallery sending
/// screens while the "1" button is on. Takes no space while it is off.
class OneTimeHint extends StatelessWidget {
  /// Creates the hint for [armed]; null (a chat with no one-time) shows nothing.
  const OneTimeHint({super.key, required this.armed, this.inGroup = false});

  /// The value the "1" button flips.
  final ValueNotifier<bool>? armed;

  /// Whether the chat is a group, where the rules differ (see [Text] below).
  final bool inGroup;

  @override
  Widget build(BuildContext context) {
    final armed = this.armed;
    if (armed == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: armed,
      builder:
          (context, on, _) =>
              on
                  ? Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: Text(
                      inGroup
                          ? 'One-time: each member opens it once. Erased for '
                              'everyone within a day.'
                          : 'One-time: opens once. Erased for both of you after '
                              'you watch the reaction.',
                      key: const Key('one-time-hint'),
                      style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                    ),
                  )
                  : const SizedBox.shrink(),
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

/// The line left where erased one-time media was, e.g. "One-time photo ·
/// reacted"; "not opened" when it was erased unopened after 14 days.
///
/// ponytail: opened is taken to mean reacted, since a one-timer opens only
/// with the camera on; an opening whose recording failed still reads
/// "reacted".
String oneTimeTrace(String? mediaType, {required bool opened}) =>
    '${oneTimeLabel(mediaType)} · ${opened ? 'reacted' : 'not opened'}';

/// The line a group one-timer leaves once erased, such as
/// "One-time photo · 5 of 7 reacted".
String groupOneTimeTrace(String? mediaType, int? reacted, int? recipients) =>
    '${oneTimeLabel(mediaType)} · ${reacted ?? 0} of ${recipients ?? 0} reacted';

/// The label for a one-time [mediaType] (`image`, `video`, anything else).
String oneTimeLabel(String? mediaType) => switch (mediaType) {
  'image' => 'One-time photo',
  'video' => 'One-time video',
  _ => 'One-time media',
};
