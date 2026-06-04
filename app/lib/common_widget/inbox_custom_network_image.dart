import 'dart:io';

import 'package:reacti_app/gen/colors.gen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';

import '../gen/assets.gen.dart';

/// A cached network image tuned for chat-inbox media bubbles.
///
/// Like [CustomNetworkImage] but, while the remote image loads, it shows the
/// locally cached file ([localPath]) if one exists — so a just-sent image
/// appears instantly before the upload finishes — otherwise a Cupertino
/// spinner. Falls back to a "no image" SVG on error.
class InboxCustomNetworkImage extends StatelessWidget {
  /// The remote image URL to load.
  final String urls;

  /// Optional fixed width; defaults to filling available width.
  final double? width;

  /// Optional fixed height.
  final double? height;

  /// Optional corner radius applied via [ClipRRect]; defaults to 0.
  final double? borderRadius;

  /// How the image should be inscribed into its box; defaults to cover.
  final BoxFit? fit;

  /// Optional path to a local file shown as the loading placeholder.
  final String? localPath;

  /// Creates an [InboxCustomNetworkImage] for the given [urls].
  const InboxCustomNetworkImage({
    super.key,
    required this.urls,
    this.width,
    this.height,
    this.borderRadius,
    this.fit,
    this.localPath,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 0.0),
      child: CachedNetworkImage(
        imageUrl: urls,
        width: width ?? double.infinity,
        height: height,
        fit: fit ?? BoxFit.cover,
        placeholder:
            (context, url) =>
                localPath != null && File(localPath!).existsSync()
                    ? Image.file(
                      File(localPath!),
                      width: width ?? double.infinity,
                      height: height,
                      fit: fit ?? BoxFit.cover,
                    )
                    : CupertinoActivityIndicator(color: AppColors.cFFFFFF),

        // Shimmer.fromColors(
        //   baseColor: Colors.grey[300]!,
        //   highlightColor: Colors.grey[100]!,
        //   child: Container(
        //     // width: 100.w,
        //     // height: 100.h,
        //     color: Colors.white,
        //   ),
        // ),
        errorWidget:
            (context, url, error) => SvgPicture.asset(
              Assets.images.noImage.path,
              fit: fit ?? BoxFit.cover,
            ),
      ),
    );
  }
}
