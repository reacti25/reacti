import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A white rounded card container with a soft drop shadow.
///
/// Provides the app's standard surface styling so screens can wrap content
/// in a consistent elevated card without repeating decoration code.
class CustomContainer extends StatelessWidget {
  /// The content rendered inside the card.
  final Widget child;

  /// Optional outer margin; defaults to no margin.
  final EdgeInsetsGeometry? margin;

  /// Optional inner padding; defaults to a screen-scaled 16 on all sides.
  final EdgeInsetsGeometry? padding;

  /// Optional corner radius; defaults to a screen-scaled 24.
  final double? borderRadius;

  /// Creates a [CustomContainer] wrapping [child].
  const CustomContainer({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? 24.r),
        boxShadow: [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 5,
            offset: Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
