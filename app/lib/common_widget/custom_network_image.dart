import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';

import '../gen/assets.gen.dart';
import '../theme/app_theme.dart';

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
    // Decode at the slot's on-screen width (physical px), not the source
    // resolution — these are small avatars/thumbnails, so a full-res decode
    // wastes memory. memCacheWidth caps the in-memory decode; the disk cache
    // keeps the full file.
    final decodeWidth =
        ((width ?? 90.w) * MediaQuery.of(context).devicePixelRatio).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 0.0),
      child: CachedNetworkImage(
        imageUrl: urls,
        width: width ?? 90.w,
        height: height ?? 70.h,
        fit: BoxFit.cover,
        memCacheWidth: decodeWidth,
        placeholder:
            (context, url) => Shimmer.fromColors(
              baseColor: context.reacti.avatarPlaceholderBg,
              highlightColor: context.reacti.hairline,
              child: Container(
                width: width ?? 90.w,
                height: height ?? 70.h,
                color: context.reacti.avatarPlaceholderBg,
              ),
            ),
        errorWidget:
            (context, url, error) => Container(
              width: width ?? 90.w,
              height: height ?? 70.h,
              color: context.reacti.avatarPlaceholderBg,
              child: SvgPicture.asset(
                Assets.images.noImage.path,
                fit: BoxFit.cover,
              ),
            ),
      ),
    );
  }
}
