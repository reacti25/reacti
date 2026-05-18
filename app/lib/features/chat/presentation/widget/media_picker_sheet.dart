import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';

/// The bottom-sheet body offering the four media-attachment sources.
///
/// Shown via `showModalBottomSheet` from both `InboxScreen` and
/// `GroupInboxScreen`, which carried a byte-identical inline copy. Each row
/// is a labelled tap target wired to one of the four callbacks; the screens
/// supply callbacks that dismiss the sheet and then invoke the matching
/// `ImagePicker` flow, so this widget stays free of picker/navigation
/// logic.
class MediaPickerSheet extends StatelessWidget {
  /// Creates the media-picker sheet body.
  ///
  /// Each callback is invoked when its row is tapped: [onPickGalleryImage]
  /// and [onPickCameraImage] for stills, [onPickGalleryVideo] and
  /// [onPickCameraVideo] for video.
  const MediaPickerSheet({
    super.key,
    required this.onPickGalleryImage,
    required this.onPickCameraImage,
    required this.onPickGalleryVideo,
    required this.onPickCameraVideo,
  });

  /// Invoked when "Pick Image from Gallery" is tapped.
  final VoidCallback onPickGalleryImage;

  /// Invoked when "Pick Image from Camera" is tapped.
  final VoidCallback onPickCameraImage;

  /// Invoked when "Pick Video from Gallery" is tapped.
  final VoidCallback onPickGalleryVideo;

  /// Invoked when "Pick Video from Camera" is tapped.
  final VoidCallback onPickCameraVideo;

  /// Builds a single labelled, tappable row of the sheet.
  Widget _option(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: TextFontStyle.headline16w400CFFFFFFPoppins),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 26.h),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 14.h,
        children: [
          _option('Pick Image from Gallery', onPickGalleryImage),
          _option('Pick Image from Camera', onPickCameraImage),
          _option('Pick Video from Gallery', onPickGalleryVideo),
          _option('Pick Video from Camera', onPickCameraVideo),
        ],
      ),
    );
  }
}
