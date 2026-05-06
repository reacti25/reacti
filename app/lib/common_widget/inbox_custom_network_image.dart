import 'dart:io';

import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';

import '../gen/assets.gen.dart';

class InboxCustomNetworkImage extends StatelessWidget {
  final String urls;
  final double? width;
  final double? height;
  final double? borderRadius;
  final BoxFit? fit;
  final String? localPath;

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
