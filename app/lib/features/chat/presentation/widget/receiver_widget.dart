// // ignore_for_file: must_be_immutable

// import 'package:flick_video_player/flick_video_player.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

// import '../../../../common_widget/custom_network_image.dart';
// import '../../../../common_widget/inbox_custom_network_image.dart';
// import '../../../../constants/text_font_style.dart';
// import '../../../../helpers/loading_helper.dart';
// import '../../../../helpers/video_controller_cache.dart';
// import '../../../../networks/api_access.dart';
// import 'custom_video_controls.dart';

// class ReceiverWidget extends StatefulWidget {
//   ReceiverWidget({
//     super.key,
//     required this.message,
//     required this.avatar,
//     this.time,
//     this.file,
//     this.fileType,
//     required this.isBlurred,
//     required this.messageId,
//     this.userId,
//     required this.onUnblur, // ✅ Added callback
//   });

//   final String message;
//   final String avatar;
//   final String? time;
//   final String? file;
//   final String? fileType;
//   bool isBlurred;
//   final int? messageId;
//   final int? userId;
//   final VoidCallback onUnblur; // ✅ Callback to parent

//   @override
//   State<ReceiverWidget> createState() => _ReceiverWidgetState();
// }

// class _ReceiverWidgetState extends State<ReceiverWidget>
//     with AutomaticKeepAliveClientMixin {
//   @override
//   bool get wantKeepAlive => true;

//   bool get hasMessage => widget.message.trim().isNotEmpty;
//   bool get hasFile => widget.file != null && widget.file!.isNotEmpty;

//   bool _isBlurred = true;

//   FlickManager? _flickManager;

//   @override
//   void initState() {
//     super.initState();
//     _isBlurred = widget.isBlurred;

//     // Check if file type is video and file exists
//     if (widget.fileType == 'video' && hasFile) {
//       _flickManager = VideoControllerCache.getFlickManager(widget.file!);

//       _flickManager?.flickVideoManager?.videoPlayerController?.addListener(
//         _videoListener,
//       );
//     }
//   }

//   void _videoListener() {
//     final controller = _flickManager?.flickVideoManager?.videoPlayerController;
//     if (controller == null) return;

//     try {
//       if (controller.value.isInitialized && controller.value.isPlaying) {
//         VideoControllerCache.pauseAllOtherVideos(widget.file!);
//       }
//     } catch (_) {
//       // Catch "used after disposed" errors in case of race conditions
//     }
//   }

//   @override
//   void dispose() {
//     _flickManager?.flickVideoManager?.videoPlayerController?.removeListener(
//       _videoListener,
//     );
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//     return Align(
//       alignment: Alignment.centerLeft,
//       child: ConstrainedBox(
//         constraints: BoxConstraints(
//           maxWidth: MediaQuery.of(context).size.width * 0.75,
//         ),
//         child: Padding(
//           padding: EdgeInsets.only(bottom: 24.h),
//           child: Stack(
//             clipBehavior: Clip.none,
//             children: [
//               Padding(
//                 padding: EdgeInsets.only(left: 38.w),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     if (hasMessage)
//                       Container(
//                         margin: EdgeInsets.only(bottom: hasFile ? 10.h : 0),
//                         padding: EdgeInsets.symmetric(
//                           horizontal: 10.w,
//                           vertical: 6.h,
//                         ),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFF1A1E0A),
//                           borderRadius: BorderRadius.only(
//                             topRight: Radius.circular(8.r),
//                             bottomRight: Radius.circular(8.r),
//                             topLeft: Radius.circular(8.r),
//                           ),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Text(
//                               widget.message,
//                               style: TextFontStyle.headline16w500CFFFFFFPoppins
//                                   .copyWith(fontSize: 12.5.sp),
//                             ),
//                             SizedBox(height: 4.h),
//                             Text(
//                               widget.time ?? "",
//                               style: TextFontStyle.headline14w400CCCCCCCPoppins
//                                   .copyWith(
//                                     fontSize: 10.sp,
//                                     color: Colors.white70,
//                                   ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     if (hasFile) _buildFilePreview(context, widget.file!),
//                   ],
//                 ),
//               ),
//               Positioned(
//                 bottom: 0,
//                 left: 0,
//                 child: ClipOval(
//                   child: CustomNetworkImage(
//                     urls: widget.avatar,
//                     width: 30.w,
//                     height: 30.h,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildFilePreview(BuildContext context, String file) {
//     if (widget.fileType == 'image') {
//       return ClipRRect(
//         borderRadius: BorderRadius.circular(8.r),
//         child: Column(
//           children: [
//             if (!_isBlurred)
//               ConstrainedBox(
//                 constraints: BoxConstraints(maxHeight: 200.h),
//                 child: InboxCustomNetworkImage(
//                   urls: widget.file!,
//                   width: double.infinity,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             if (_isBlurred)
//               InkWell(
//                 onTap: () {
//                   if (_isBlurred) {
//                     // Call the API to unblur the image and notify parent
//                     viewInboxImageRx
//                         .viewInboxImage(id: widget.messageId!)
//                         .waitingForSuccess()
//                         .then((value) async {
//                           if (value) {
//                             // ✅ Update local state immediately
//                             setState(() {
//                               _isBlurred = false;
//                             });

//                             // ✅ Notify parent to update its state
//                             widget.onUnblur();
//                           }
//                         });
//                   }
//                 },
//                 child: Container(
//                   padding: EdgeInsets.all(12.sp),
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.white30),
//                     borderRadius: BorderRadius.circular(12.r),
//                   ),
//                   child: Column(
//                     spacing: 12.sp,
//                     children: [
//                       Icon(Icons.image, color: Colors.white70),
//                       Text(
//                         "Click to view the media",
//                         style: TextFontStyle.headline14w400CCCCCCCPoppins
//                             .copyWith(fontSize: 12.sp, color: Colors.white70),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       );
//     } else if (widget.fileType == 'video') {
//       return Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(12.r),
//           border: Border.all(color: Colors.white54),
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(12.r),
//           child:
//               _flickManager != null
//                   ? GestureDetector(
//                     onTap: () {
//                       // Navigator.push(
//                       //   context,
//                       //   MaterialPageRoute(
//                       //     builder:
//                       //         (context) => VideoViewScreen(url: widget.file!),
//                       //   ),
//                       // );
//                     },
//                     child: ValueListenableBuilder(
//                       valueListenable:
//                           _flickManager!
//                               .flickVideoManager!
//                               .videoPlayerController!,
//                       builder: (context, value, child) {
//                         return ConstrainedBox(
//                           constraints: BoxConstraints(maxHeight: 200.h),
//                           child: FlickVideoPlayer(
//                             key: ValueKey(_flickManager),
//                             flickManager: _flickManager!,
//                             flickVideoWithControls:
//                                 const FlickVideoWithControls(
//                                   videoFit: BoxFit.cover,
//                                   controls: CustomFlickPortraitControls(),
//                                 ),
//                           ),
//                         );
//                       },
//                     ),
//                   )
//                   : const CircularProgressIndicator(),
//         ),
//       );
//     }
//     return const SizedBox.shrink();
//   }
// }
