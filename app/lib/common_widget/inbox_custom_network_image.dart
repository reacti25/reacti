import 'dart:io';

import 'package:reacti_app/gen/colors.gen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_thumbhash/flutter_thumbhash.dart';

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

  /// Optional base64 ThumbHash — a ~20-byte encoding of the image decoded to a
  /// tiny blurred preview, shown instantly while the real image downloads so
  /// the bubble is never a blank box or bare spinner.
  final String? thumbHash;

  /// Creates an [InboxCustomNetworkImage] for the given [urls].
  const InboxCustomNetworkImage({
    super.key,
    required this.urls,
    this.width,
    this.height,
    this.borderRadius,
    this.fit,
    this.localPath,
    this.thumbHash,
  });

  /// Decodes [thumbHash] to a blurred placeholder image, or null when there's
  /// no hash or it can't be decoded (falls through to the spinner).
  Widget? _thumbHashPlaceholder() {
    final hash = thumbHash;
    if (hash == null || hash.isEmpty) {
      return null;
    }
    try {
      return Image(
        image: ThumbHash.fromBase64(hash).toImage(),
        width: width ?? double.infinity,
        height: height,
        fit: fit ?? BoxFit.cover,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Decode no larger than the screen is wide, in physical pixels. Chat
    // bubbles (and the smaller reply quotes) never render wider than the
    // screen, so decoding a multi-megapixel source at full resolution just
    // wastes decode time, memory and paint latency. memCacheWidth caps the
    // in-memory decode only; the on-disk cache keeps the full file, so nothing
    // downstream loses resolution. Height is left to scale with aspect ratio.
    final decodeWidth = (media.size.width * media.devicePixelRatio).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 0.0),
      child: CachedNetworkImage(
        imageUrl: urls,
        width: width ?? double.infinity,
        height: height,
        fit: fit ?? BoxFit.cover,
        memCacheWidth: decodeWidth,
        placeholder: (context, url) {
          // Local file (optimistic send) is the best placeholder; then the
          // ThumbHash blur; finally a spinner.
          if (localPath != null && File(localPath!).existsSync()) {
            return Image.file(
              File(localPath!),
              width: width ?? double.infinity,
              height: height,
              fit: fit ?? BoxFit.cover,
            );
          }
          return _thumbHashPlaceholder() ??
              CupertinoActivityIndicator(color: AppColors.cFFFFFF);
        },

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
