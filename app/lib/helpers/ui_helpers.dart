import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'navigation_service.dart';

/// Contains useful consts to reduce boilerplate and duplicate code
///
/// Exposes a standard scale of [SizedBox] spacers and padding values so
/// layouts across the app stay visually consistent. All sizes are scaled
/// with `flutter_screenutil` for responsive sizing.
final class UIHelper {
  /// Private constructor — this class is a static-only utility.
  UIHelper._();

  /// Screen-scaled width unit for small vertical gaps.
  // Vertical spacing constants. Adjust to your liking.
  static final double _verticalSpaceSmall = 10.0.w;

  /// Screen-scaled width unit for medium vertical gaps.
  static final double _verticalSpaceMedium = 20.0.w;

  /// Screen-scaled width unit for medium-large vertical gaps.
  // ignore: unused_field
  static final double _verticalSpaceMediumLarge = 25.0.w;

  /// Screen-scaled width unit for semi-large vertical gaps.
  static final double _verticalSpaceSemiLarge = 40.0.w;

  /// Screen-scaled width unit for large vertical gaps.
  static final double _verticalSpaceLarge = 60.0.w;

  /// Screen-scaled width unit for extra-large vertical gaps.
  static final double _verticalSpaceExtraLarge = 100.0.w;

  /// Screen-scaled height unit for small horizontal gaps.
  // Vertical spacing constants. Adjust to your liking.
  static final double _horizontalSpaceSmall = 10.0.h;

  /// Screen-scaled height unit for medium horizontal gaps.
  static final double _horizontalSpaceMedium = 20.0.h;

  /// Screen-scaled height unit for semi-large horizontal gaps.
  static final double _horizontalSpaceSemiLarge = 40.0.h;

  /// Screen-scaled height unit for large horizontal gaps.
  static final double _horizontalSpaceLarge = 60.0.h;

  /// A small vertical spacer widget.
  static Widget verticalSpaceSmall = SizedBox(height: _verticalSpaceSmall);

  /// A medium vertical spacer widget.
  static Widget verticalSpaceMedium = SizedBox(height: _verticalSpaceMedium);

  /// A medium-large vertical spacer widget.
  static Widget verticalSpaceMediumLarge = SizedBox(
    height: _verticalSpaceMediumLarge,
  );

  /// A semi-large vertical spacer widget.
  static Widget verticalSpaceSemiLarge = SizedBox(
    height: _verticalSpaceSemiLarge,
  );

  /// A large vertical spacer widget.
  static Widget verticalSpaceLarge = SizedBox(height: _verticalSpaceLarge);

  /// An extra-large vertical spacer widget.
  static Widget verticalSpaceExtraLarge = SizedBox(
    height: _verticalSpaceExtraLarge,
  );

  /// A small horizontal spacer widget.
  static Widget horizontalSpaceSmall = SizedBox(width: _horizontalSpaceSmall);

  /// A medium horizontal spacer widget.
  static Widget horizontalSpaceMedium = SizedBox(width: _horizontalSpaceMedium);

  /// A semi-large horizontal spacer widget.
  static Widget horizontalSpaceSemiLarge = SizedBox(
    width: _horizontalSpaceSemiLarge,
  );

  /// A large horizontal spacer widget.
  static Widget horizontalSpaceLarge = SizedBox(width: _horizontalSpaceLarge);

  /// Returns a horizontal spacer of the given [width].
  static Widget horizontalSpace(double width) => SizedBox(width: width);

  /// Returns a vertical spacer of the given [height].
  static Widget verticalSpace(double height) => SizedBox(height: height);

  /// Returns the top safe-area inset (e.g. status bar / notch height).
  ///
  /// Reads from the global navigator context so it can be used without a
  /// local [BuildContext].
  static double safePadding() =>
      MediaQuery.of(NavigationService.context).padding.top;

  //   static Widget customDivider({required double? width}) => Container(
  //         height: .6.h,
  //         color: AppColors.cDFE3E8,
  //         width: width ?? double.infinity,
  //       );

  /// Returns the app's default screen-edge padding value.
  static double kDefaulutPadding() => 20.sp;
}
