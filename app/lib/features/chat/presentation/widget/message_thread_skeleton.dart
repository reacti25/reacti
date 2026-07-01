import 'package:reacti_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholder for a conversation thread while it loads.
///
/// Branch 3.1 of `docs/PLAN-media-timing-and-speed-2026-06-23.md`: replaces the
/// bare `CircularProgressIndicator` on the 1:1 and group inbox screens with a
/// skeleton of chat bubbles, so the wait reads as "messages loading" instead of
/// a blank spinner — matching the shimmer already used on the chat list.
///
/// Purely cosmetic and stateless: a fixed set of alternating-side bubbles of
/// varied widths. No data, no controllers.
class MessageThreadSkeleton extends StatelessWidget {
  /// Creates the thread-loading skeleton.
  const MessageThreadSkeleton({super.key});

  // Side (true = incoming/left) and relative width for each placeholder bubble.
  // ponytail: a hand-picked pattern reads more like a real thread than a loop.
  static const List<(bool, double)> _bubbles = [
    (true, 0.55),
    (false, 0.45),
    (true, 0.70),
    (false, 0.60),
    (true, 0.40),
    (false, 0.50),
    (true, 0.65),
    (false, 0.35),
  ];

  @override
  Widget build(BuildContext context) {
    final maxBubble = MediaQuery.of(context).size.width * 0.72;

    final onSurface = context.appColors.onSurface;
    return Shimmer.fromColors(
      baseColor: onSurface.withValues(alpha: 0.18),
      highlightColor: onSurface.withValues(alpha: 0.45),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final (incoming, widthFactor) in _bubbles)
            Align(
              alignment:
                  incoming ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: maxBubble * widthFactor,
                height: 38.h,
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: onSurface,
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
