import 'package:flutter/material.dart';

/// Spacing helpers that keep layout boilerplate to a single call.
///
/// Use [verticalSpace] / [horizontalSpace] to drop a [SizedBox] of a given
/// extent between widgets. A scale of pre-sized named spacers
/// (`verticalSpaceSmall` … `Large`) plus `safePadding`/`kDefaulutPadding` used
/// to live here, but had no callers — removed (call sites pass the size
/// directly, e.g. `UIHelper.verticalSpace(12.h)`).
final class UIHelper {
  /// Private constructor — this class is a static-only utility.
  UIHelper._();

  /// Returns a horizontal spacer of the given [width].
  static Widget horizontalSpace(double width) => SizedBox(width: width);

  /// Returns a vertical spacer of the given [height].
  static Widget verticalSpace(double height) => SizedBox(height: height);
}
