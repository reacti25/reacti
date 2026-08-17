import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/app_theme.dart';

/// The four steps of a Reacti, in order.
///
/// Kept as data rather than four hand-written rows: the numbering is derived,
/// so a step can be added or reworded without renumbering anything by hand.
/// Jonjon's copy (2026-08-17): three steps, not four. The old version spent
/// two of them on the seal; one step for the reveal and one for the capture is
/// the same story with less to read before the button.
const List<String> _steps = [
  'Send a photo or video.',
  'They tap to reveal it.',
  'Reacti captures their genuine first reaction and sends it back to you.',
];

/// Opens the "How a Reacti works" sheet and completes when it is dismissed.
///
/// The coach marks around it can only teach geography — which tab, which
/// button. They cannot teach the mechanic, because the mechanic needs two
/// people and a message, and the account seeing this walkthrough has neither.
/// Four lines of plain text is the cheapest thing that closes that gap, and it
/// runs *before* the marks so the geography arrives with a reason attached.
///
/// ponytail: a bottom sheet, not a screen and not a carousel. The carousel was
/// retired on purpose (PR #413); this is one dismissible card.
Future<void> showTourRecapSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _TourRecapSheet(),
  );
}

/// Body of the walkthrough's opening card.
class _TourRecapSheet extends StatelessWidget {
  const _TourRecapSheet();

  /// One numbered step: a filled brand circle carrying [index] + 1, and the
  /// step's [text] beside it.
  Widget _step(BuildContext context, int index, String text) {
    final reacti = context.reacti;
    return Padding(
      padding: EdgeInsets.only(bottom: 18.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26.w,
            height: 26.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reacti.brandFill,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: reacti.onBrandFill,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3.h),
              child: Text(
                text,
                style: TextStyle(
                  color: reacti.textPrimary,
                  fontSize: 15.sp,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reacti = context.reacti;
    return Container(
      width: double.infinity,
      // Large accessibility text sizes push four steps plus a button past a
      // short screen; the sheet scrolls rather than clipping the last step.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 28.h),
      decoration: BoxDecoration(
        color: reacti.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 22.h),
                  decoration: BoxDecoration(
                    color: reacti.hairline,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Text(
                'How a Reacti works',
                style: TextStyle(
                  color: reacti.textPrimary,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 20.h),
              for (var i = 0; i < _steps.length; i++)
                _step(context, i, _steps[i]),
              SizedBox(height: 6.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: reacti.brandFill,
                    foregroundColor: reacti.onBrandFill,
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                  ),
                  child: Text(
                    // Names the one thing this walkthrough is for. "Show me
                    // around" promised a tour of the app; what follows now is
                    // at most a single tip.
                    'Send my first Reacti',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
