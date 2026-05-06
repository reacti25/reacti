// import 'package:achiar_expert_app/constants/text_font_style.dart';
// import 'package:achiar_expert_app/gen/colors.gen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:flutter_svg/svg.dart';

// class CustomIconOutlineButton extends StatelessWidget {
//   final VoidCallback onTap;
//   final String btnName;
//   final String? icon;
//   final double? height;
//   final double? width;
//   final Color? borderColor;
//   const CustomIconOutlineButton({
//     super.key,
//     required this.onTap,
//     required this.btnName,
//     this.icon,
//     this.height,
//     this.width,
//     this.borderColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: width ?? double.maxFinite,
//       height: height ?? 45.h,
//       child: OutlinedButton(
//         style: OutlinedButton.styleFrom(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14.r),
//           ),
//           side: BorderSide(
//             color: borderColor ?? AppColors.allPrimaryColor,
//             width: 1.w,
//           ),
//         ),
//         onPressed: onTap,
//         child: Row(
//           spacing: 8.w,
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(btnName, style: TextFontStyle.headline16w400C5A5C5FInter),
//             icon != null ? SvgPicture.asset(icon!) : SizedBox.shrink(),
//           ],
//         ),
//       ),
//     );
//   }
// }
