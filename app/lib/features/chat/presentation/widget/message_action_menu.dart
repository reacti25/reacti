import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';

/// A single selectable row in the [showMessageActionMenu] popup.
///
/// Purely a value object describing one action (its [icon], [label] and the
/// [onTap] to run once the menu closes). The menu itself owns presentation and
/// dismissal, so callers only supply intent — matching how the chat screens
/// keep message logic in the screen, not the bubble widgets.
class MessageAction {
  /// Creates an action row.
  ///
  /// [isDestructive] tints the row in the error colour (used for delete).
  const MessageAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  /// Leading icon shown before [label].
  final IconData icon;

  /// Human-readable action name, e.g. "Reply".
  final String label;

  /// Invoked after the menu has been dismissed.
  final VoidCallback onTap;

  /// Whether to render the row as a destructive action (red).
  final bool isDestructive;
}

/// Shows a WhatsApp-style long-press action menu anchored near [tapPosition].
///
/// Dims and blurs the conversation behind a barrier, then animates a small
/// card of [actions] in with a scale+fade. The card is clamped to stay fully
/// on-screen relative to where the user pressed. Tapping an action (or the
/// barrier) dismisses the menu; a tapped action then runs its callback.
///
/// [tapPosition] is the global position of the long-press (from
/// `onLongPressStart`). Returns when the menu is dismissed.
///
/// ponytail: the pressed bubble is focused via the dim+blur barrier rather than
/// re-hosting a floating copy of it. A literal bitmap "lift" of the exact
/// bubble is deferred — cloning a reaction/video bubble would duplicate its
/// live player controller, which sits on the patented recording path.
Future<void> showMessageActionMenu(
  BuildContext context, {
  required Offset tapPosition,
  required List<MessageAction> actions,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, _, _) {
      return _MessageActionMenuOverlay(
        animation: animation,
        tapPosition: tapPosition,
        actions: actions,
      );
    },
  );
}

/// The animated overlay body for [showMessageActionMenu]: a blurred backdrop
/// plus the positioned, scaling action card.
class _MessageActionMenuOverlay extends StatelessWidget {
  const _MessageActionMenuOverlay({
    required this.animation,
    required this.tapPosition,
    required this.actions,
  });

  final Animation<double> animation;
  final Offset tapPosition;
  final List<MessageAction> actions;

  /// Fixed card width; also used to keep the card clamped on-screen.
  static const double _cardWidth = 216;

  /// Estimated per-row height, used to clamp the card vertically before its
  /// real size is known.
  static const double _rowHeight = 48;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = _cardWidth.w;
    final estHeight = actions.length * _rowHeight.h + 8.h;

    // Anchor to the press point but keep the whole card within the safe area.
    final left = tapPosition.dx.clamp(12.w, size.width - cardWidth - 12.w);
    final top = tapPosition.dy.clamp(
      MediaQuery.of(context).padding.top + 12.h,
      size.height - estHeight - 24.h,
    );

    return Stack(
      children: [
        // Blurred, dimmed backdrop that fades in with the menu.
        Positioned.fill(
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: animation,
              alignment: Alignment.topLeft,
              child: _MenuCard(width: cardWidth, actions: actions),
            ),
          ),
        ),
      ],
    );
  }
}

/// The rounded card listing the [actions].
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.width, required this.actions});

  final double width;
  final List<MessageAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(14.r),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              _MenuRow(action: action, color: scheme.onSurface),
          ],
        ),
      ),
    );
  }
}

/// One tappable row; dismisses the menu before running [MessageAction.onTap].
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.action, required this.color});

  final MessageAction action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rowColor =
        action.isDestructive ? Theme.of(context).colorScheme.error : color;
    return InkWell(
      onTap: () {
        // Close the menu first so the action runs against the chat, not the
        // dialog route.
        Navigator.of(context).pop();
        action.onTap();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(action.icon, size: 20.sp, color: rowColor),
            SizedBox(width: 14.w),
            Text(
              action.label,
              style: TextFontStyle.headline16w500C333333Poppins.copyWith(
                color: rowColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
