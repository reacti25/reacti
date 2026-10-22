import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../theme/app_theme.dart';

/// A media message and the reactions it collected, framed as one block.
///
/// Separates each media from its reactions in a group thread: a hairline
/// frame with an accent rail on the left, the [original] bubble on top and
/// every reaction bubble indented beneath it. [footer] is the react-to-unlock
/// strip shown while other members' reactions are still withheld. Pure
/// layout: the bubbles keep their own tap, long-press and reaction wiring.
class GroupReactionCluster extends StatelessWidget {
  /// Creates the cluster frame.
  const GroupReactionCluster({
    super.key,
    required this.original,
    required this.reactions,
    this.footer,
  });

  /// The media message bubble that heads the cluster.
  final Widget original;

  /// Reaction bubbles answering [original], oldest-first.
  final List<Widget> reactions;

  /// Optional strip under the reactions (the lock notice).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: context.reacti.hairline),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3.w,
            child: ColoredBox(color: accent),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(11.w, 8.h, 8.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                original,
                for (final reaction in reactions)
                  Padding(
                    padding: EdgeInsets.only(left: 16.w),
                    child: reaction,
                  ),
                if (footer != null) footer!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
