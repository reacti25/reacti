import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
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
