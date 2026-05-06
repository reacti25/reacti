// import 'dart:io';

// import 'package:achiar_expert_app/features/chat/presentation/widget/custom_video_controls.dart';
// import 'package:flick_video_player/flick_video_player.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_cache_manager/flutter_cache_manager.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:video_player/video_player.dart';

// import '../../../constants/text_font_style.dart';
// import '../../../helpers/navigation_service.dart';

// class VideoViewScreen extends StatefulWidget {
//   final String url;
//   const VideoViewScreen({super.key, required this.url});

//   @override
//   State<VideoViewScreen> createState() => _VideoViewScreenState();
// }

// class _VideoViewScreenState extends State<VideoViewScreen> {
//   FlickManager? _flickManager;
//   late Future<FileInfo?> _cacheFuture;

//   @override
//   void initState() {
//     super.initState();
//     _cacheFuture = DefaultCacheManager().getFileFromCache(widget.url);
//   }

//   @override
//   void didUpdateWidget(covariant VideoViewScreen oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.url != widget.url) {
//       _flickManager?.dispose();
//       _flickManager = null;
//       _cacheFuture = DefaultCacheManager().getFileFromCache(widget.url);
//       setState(() {});
//     }
//   }

//   @override
//   void dispose() {
//     _flickManager?.dispose();
//     super.dispose();
//   }

//   void _createFlickManager({File? cachedFile}) {
//     if (_flickManager != null) return;

//     if (cachedFile != null) {
//       _flickManager = FlickManager(
//         videoPlayerController: VideoPlayerController.file(cachedFile),
//         autoPlay: false,
//         autoInitialize: true,
//       );
//     } else {
//       _flickManager = FlickManager(
//         videoPlayerController: VideoPlayerController.network(widget.url),
//         autoPlay: false,
//         autoInitialize: true,
//       );

//       // cache in background (optional)
//       DefaultCacheManager().downloadFile(widget.url);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         height: double.infinity,
//         width: double.infinity,
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Color(0xFF000000),
//               Color(0xFF000000),
//             ], // Changed gradient to black for better video experience
//           ),
//         ),
//         child: SafeArea(
//           child: Stack(
//             children: [
//               // ✅ Video stays centered relative to the whole screen
//               Center(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 0.w),
//                   child: FutureBuilder<FileInfo?>(
//                     future: _cacheFuture,
//                     builder: (context, snap) {
//                       if (snap.connectionState != ConnectionState.done) {
//                         return const CircularProgressIndicator();
//                       }

//                       final cachedFile = snap.data?.file;

//                       // ✅ Create manager AFTER build frame
//                       WidgetsBinding.instance.addPostFrameCallback((_) {
//                         if (!mounted) return;
//                         _createFlickManager(cachedFile: cachedFile);
//                         if (mounted) setState(() {});
//                       });

//                       if (_flickManager == null) {
//                         return const CircularProgressIndicator();
//                       }

//                       return AspectRatio(
//                         aspectRatio: 16 / 9,
//                         child: FlickVideoPlayer(
//                           flickManager: _flickManager!,
//                           flickVideoWithControls: const FlickVideoWithControls(
//                             videoFit: BoxFit.contain,
//                             controls: CustomFlickPortraitControls(),
//                           ),
//                           flickVideoWithControlsFullscreen:
//                               const FlickVideoWithControls(
//                                 videoFit: BoxFit.contain,
//                                 controls: CustomFlickLandscapeControls(),
//                               ),
//                           preferredDeviceOrientationFullscreen: const [
//                             DeviceOrientation.landscapeLeft,
//                             DeviceOrientation.landscapeRight,
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               ),

//               // ✅ Header pinned to top
//               Align(
//                 alignment: Alignment.topCenter,
//                 child: Container(
//                   padding: EdgeInsets.symmetric(horizontal: 16.w),
//                   height: kToolbarHeight,
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       InkWell(
//                         onTap: () => NavigationService.goBack,
//                         child: const Icon(
//                           Icons.arrow_back,
//                           color: Colors.white,
//                           size: 30,
//                         ),
//                       ),
//                       Text(
//                         "Video",
//                         style: TextFontStyle.headline20w600CFFFFFFPoppins,
//                       ),
//                       const SizedBox(height: 30, width: 30),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
