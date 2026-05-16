import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';

import '../gen/assets.gen.dart';
import '../gen/colors.gen.dart';

/// A cached network image with a shimmer placeholder and error fallback.
///
/// Wraps [CachedNetworkImage] in a [ClipRRect], showing a shimmer effect
/// while loading and a "no image" SVG on failure. Reused wherever remote
/// images are displayed (e.g. avatars, thumbnails) outside the chat inbox.
class CustomNetworkImage extends StatelessWidget {
  /// The remote image URL to load.
  final String urls;

  /// Optional fixed width; defaults to a screen-scaled 90.
  final double? width;

  /// Optional fixed height; defaults to a screen-scaled 70.
  final double? height;

  /// Optional corner radius applied via [ClipRRect]; defaults to 0.
  final double? borderRadius;

  /// Creates a [CustomNetworkImage] for the given [urls].
  const CustomNetworkImage({
    super.key,
    required this.urls,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 0.0),
      child: CachedNetworkImage(
        imageUrl: urls,
        width: width ?? 90.w,
        height: height ?? 70.h,
        fit: BoxFit.cover,
        placeholder:
            (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: width ?? 90.w,
                height: height ?? 70.h,
                color: Colors.white,
              ),
            ),
        errorWidget:
            (context, url, error) => Container(
              width: width ?? 90.w,
              height: height ?? 70.h,
              color: AppColors.cFFFFFF,
              child: SvgPicture.asset(
                Assets.images.noImage.path,
                fit: BoxFit.cover,
              ),
            ),
      ),
    );
  }
}
