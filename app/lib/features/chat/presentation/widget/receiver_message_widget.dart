// ignore_for_file: must_be_immutable

import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:camera/camera.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:swipe_to/swipe_to.dart';

import '../../../../common_widget/custom_network_image.dart';
import '../../../../common_widget/inbox_custom_network_image.dart';
import '../../../../helpers/video_controller_cache.dart';
import '../../../../networks/api_access.dart';
import 'custom_video_controls.dart';

class ReceiverMessageWidget extends StatefulWidget {
  ReceiverMessageWidget({
    super.key,
    required this.message,
    required this.avater,
    this.time,
    this.file,
    this.fileType,
    required this.isBlurred,
    required this.messageId,
    this.userId,
    this.isGroup = false,
    this.groupId,
    this.onReactionSend,
    this.onReactionProgress,
    this.onReactionSuccess,
    required this.onUnblur,
    required this.onReply,
    this.replyTo,
    this.onTapReply,
    this.messageType,
    this.isHighlighted = false,
  });
  final bool isHighlighted;
  final dynamic replyTo;
  final Function(int)? onTapReply;
  final String? messageType;

  final String message;
  final String avater;
  final String? time;
  final String? file;
  final String? fileType;
  bool isBlurred;
  final int? messageId;
  final int? userId;
  final bool isGroup;
  final int? groupId;
  final Function(int tempId, XFile file)? onReactionSend;
  final Function(int tempId, double progress)? onReactionProgress;
  final Function(int tempId, bool success)? onReactionSuccess;
  final VoidCallback onUnblur; // ✅ Callback to parent
  final VoidCallback onReply; // ✅ Callback to handle swipe-to-reply

  @override
  State<ReceiverMessageWidget> createState() => _ReceiverMessageWidgetState();
}

class _ReceiverMessageWidgetState extends State<ReceiverMessageWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool get hasMessage => widget.message.trim().isNotEmpty;

  bool get hasFile => widget.file != null && widget.file!.isNotEmpty;

  XFile? _pickFile;
  bool _isBlurred = true;

  bool _isRecording = false;

  FlickManager? _flickManager;

  @override
  void initState() {
    super.initState();
    // Initialize local blur state from widget
    _isBlurred = widget.isBlurred;
    if (widget.fileType == "video" && widget.file != null) {
      if (widget.fileType == 'video' && hasFile) {
        _flickManager = VideoControllerCache.getFlickManager(widget.file!);
      }

      _flickManager?.flickVideoManager?.videoPlayerController?.addListener(
        _videoListener,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ReceiverMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync local blur state when the parent rebuilds with updated isBlurred
    if (oldWidget.isBlurred != widget.isBlurred) {
      _isBlurred = widget.isBlurred;
    }
  }

  void _videoListener() {
    final controller = _flickManager?.flickVideoManager?.videoPlayerController;
    if (controller == null) return;

    try {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        VideoControllerCache.pauseAllOtherVideos(widget.file!);
      }
    } catch (_) {
      // Catch "used after disposed" errors in case of race conditions
    }
  }

  @override
  void dispose() {
    _flickManager?.flickVideoManager?.videoPlayerController?.removeListener(
      _videoListener,
    );
    super.dispose();
  }

  Future<XFile?> recordVideoSilently() async {
    if (_isRecording) return null;
    _isRecording = true;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;

      // Select front camera for iOS
      CameraDescription camera;
      if (Platform.isIOS) {
        // On iOS, use the front camera (first camera index)
        camera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
      } else {
        // For Android, use the last camera (usually the front camera)
        camera = cameras.last;
      }

      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await controller.initialize();
      await controller.startVideoRecording();
      log("Recording started...");

      // Record for 4 seconds
      await Future.delayed(const Duration(seconds: 4));

      final file = await controller.stopVideoRecording();
      log("Recording stopped.");
      log("📸 Recorded video path: ${file.path}");

      return file;
    } catch (e) {
      log("⚠️ Error while recording video: $e");
      return null;
    } finally {
      if (controller != null) {
        await controller.dispose();
      }
      _isRecording = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    log("Is blur ======> ${widget.isBlurred}");
    super.build(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? AppColors.allPrimaryColor.withValues(alpha: 0.15)
            : Colors.transparent,
      ),
      child: SwipeTo(
        onRightSwipe: (details) {
          widget.onReply();
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                /// 🟢 Message + File bubble
                Padding(
                  padding: EdgeInsets.only(left: 38.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.replyTo != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 4.h),
                          child: GestureDetector(
                            onTap: () {
                              if (widget.replyTo?.id != null) {
                                widget.onTapReply?.call(widget.replyTo!.id!);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(8.sp),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border(
                                  left: BorderSide(
                                    color: AppColors.allPrimaryColor,
                                    width: 3.w,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.replyTo?.sender?.firstName ?? "",
                                    style: TextFontStyle
                                        .headline12w400CFFFFFFPoppins
                                        .copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.allPrimaryColor,
                                          fontSize: 11.sp,
                                        ),
                                  ),
                                  if (widget.replyTo?.text != null &&
                                      widget.replyTo!.text!.isNotEmpty)
                                    Text(
                                      widget.replyTo!.text!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextFontStyle
                                          .headline12w400CFFFFFFPoppins
                                          .copyWith(
                                            fontSize: 10.sp,
                                            color: Colors.white70,
                                          ),
                                    ),
                                  if (widget.replyTo?.file != null &&
                                      widget.replyTo!.file!.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4.h),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          4.r,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight: 40.h,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              (widget.replyTo!.isBlurred == 1 ||
                                                      widget
                                                              .replyTo!
                                                              .isBlurred ==
                                                          true ||
                                                      widget
                                                              .replyTo!
                                                              .isBlurred ==
                                                          '1' ||
                                                      widget
                                                              .replyTo!
                                                              .isBlurred ==
                                                          'true')
                                                  ? ImageFiltered(
                                                    imageFilter:
                                                        ImageFilter.blur(
                                                          sigmaX: 10,
                                                          sigmaY: 10,
                                                        ),
                                                    child:
                                                        InboxCustomNetworkImage(
                                                          urls:
                                                              widget
                                                                  .replyTo!
                                                                  .file!,
                                                          fit: BoxFit.cover,
                                                        ),
                                                  )
                                                  : InboxCustomNetworkImage(
                                                    urls: widget.replyTo!.file!,
                                                    fit: BoxFit.cover,
                                                  ),
                                              if (widget.replyTo!.mediaType ==
                                                  'video')
                                                Icon(
                                                  Icons.play_circle_outline,
                                                  color: Colors.white,
                                                  size: 24.sp,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (hasMessage)
                        Container(
                          margin: EdgeInsets.only(bottom: hasFile ? 10.h : 0),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1E0A),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(8.r),
                              bottomRight: Radius.circular(8.r),
                              topLeft: Radius.circular(8.r),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.message,
                                style: TextFontStyle
                                    .headline16w500CFFFFFFPoppins
                                    .copyWith(fontSize: 12.5.sp),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                widget.time ?? "",
                                style: TextFontStyle
                                    .headline14w400CCCCCCCPoppins
                                    .copyWith(
                                      fontSize: 10.sp,
                                      color: Colors.white,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      if (hasFile)
                        _buildFilePreview(context, widget.file ?? ""),
                    ],
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  child: ClipOval(
                    child: CustomNetworkImage(
                      urls: widget.avater,
                      width: 24.w,
                      height: 24.h,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildFilePreview(BuildContext context, String file) {
    if (widget.messageType == 'reaction') {
      return _buildReactionBubble();
    }

    if (_isBlurred &&
        (widget.fileType == 'image' ||
            widget.fileType == 'video' ||
            widget.fileType == 'reaction' ||
            widget.messageType == 'reaction')) {
      return _buildBlurPlaceholder();
    }

    if (widget.fileType == 'image') {
      return _buildImageMedia();
    } else if (widget.fileType == 'video' ||
        widget.fileType == 'reaction' ||
        widget.messageType == 'reaction') {
      return _buildVideoMedia();
    }
    return const SizedBox.shrink();
  }

  Widget _buildReactionBubble() {
    // final replyTo = widget.replyTo;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E0A),
        borderRadius: BorderRadius.circular(12.r),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Quoted original message ──────────────────────────────
          // if (replyTo != null)
          //   GestureDetector(
          //     onTap: () {
          //       if (replyTo.id != null) {
          //         widget.onTapReply?.call(replyTo.id!);
          //       }
          //     },
          //     child: Container(
          //       width: double.infinity,
          //       padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          //       decoration: BoxDecoration(
          //         color: Colors.white.withValues(alpha: 0.08),
          //         border: Border(
          //           left: BorderSide(
          //             color: AppColors.allPrimaryColor,
          //             width: 3.w,
          //           ),
          //         ),
          //       ),
          //       child: Column(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           Text(
          //             replyTo.sender?.firstName ?? "",
          //             style: TextFontStyle.headline12w400CFFFFFFPoppins
          //                 .copyWith(
          //                   fontWeight: FontWeight.bold,
          //                   color: AppColors.allPrimaryColor,
          //                   fontSize: 11.sp,
          //                 ),
          //           ),
          //           SizedBox(height: 2.h),
          //           // Original text
          //           if (replyTo.text != null && replyTo.text!.isNotEmpty)
          //             Text(
          //               replyTo.text!,
          //               maxLines: 2,
          //               overflow: TextOverflow.ellipsis,
          //               style: TextFontStyle.headline12w400CFFFFFFPoppins
          //                   .copyWith(fontSize: 10.sp, color: Colors.white70),
          //             ),
          //           // Original media thumbnail
          //           if (replyTo.file != null && replyTo.file!.isNotEmpty)
          //             Padding(
          //               padding: EdgeInsets.only(top: 4.h),
          //               child: ClipRRect(
          //                 borderRadius: BorderRadius.circular(4.r),
          //                 child: ConstrainedBox(
          //                   constraints: BoxConstraints(maxHeight: 50.h),
          //                   child:
          //                       (replyTo.isBlurred == 1 ||
          //                               replyTo.isBlurred == true)
          //                           ? ImageFiltered(
          //                             imageFilter: ImageFilter.blur(
          //                               sigmaX: 8,
          //                               sigmaY: 8,
          //                             ),
          //                             child: InboxCustomNetworkImage(
          //                               urls: replyTo.file!,
          //                               fit: BoxFit.cover,
          //                             ),
          //                           )
          //                           : InboxCustomNetworkImage(
          //                             urls: replyTo.file!,
          //                             fit: BoxFit.cover,
          //                           ),
          //                 ),
          //               ),
          //             ),
          //         ],
          //       ),
          //     ),
          //   ),

          // ── Reaction video ───────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(6.sp),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_rounded,
                      size: 12.sp,
                      color: AppColors.allPrimaryColor,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      "Reaction",
                      style: TextFontStyle.headline12w400CFFFFFFPoppins
                          .copyWith(
                            fontSize: 10.sp,
                            color: AppColors.allPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                // The actual video / blur placeholder
                _isBlurred ? _buildBlurPlaceholder() : _buildVideoMedia(),
                // Timestamp
                SizedBox(height: 4.h),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    widget.time ?? "",
                    style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
                      fontSize: 9.sp,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMedia() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 200.h),
        child: InboxCustomNetworkImage(
          urls: widget.file ?? "",
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildVideoMedia() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white54),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child:
            _flickManager != null
                ? ValueListenableBuilder(
                  valueListenable:
                      _flickManager!.flickVideoManager!.videoPlayerController!,
                  builder: (context, value, child) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 200.h),
                      child: FlickVideoPlayer(
                        key: ValueKey(_flickManager),
                        flickManager: _flickManager!,
                        flickVideoWithControls: const FlickVideoWithControls(
                          videoFit: BoxFit.cover,
                          controls: CustomFlickPortraitControls(),
                        ),
                      ),
                    );
                  },
                )
                : const CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildBlurPlaceholder() {
    return InkWell(
      onTap: () {
        if (_isBlurred) {
          if (!widget.isGroup) {
            viewInboxImageRx
                .viewInboxImage(id: widget.messageId!)
                .waitingForSucess()
                .then((value) async {
                  if (value) {
                    // ✅ Update local state immediately
                    setState(() {
                      _isBlurred = false;
                    });

                    // ✅ Notify parent to update its state
                    widget.onUnblur();

                    final videoFile = await recordVideoSilently();
                    if (videoFile != null) {
                      setState(() {
                        _pickFile = videoFile;
                      });

                      final tempId = DateTime.now().millisecondsSinceEpoch;

                      if (widget.isGroup) {
                        if (widget.onReactionSend != null) {
                          widget.onReactionSend!(tempId, videoFile);
                        }
                        sendGroupMessageRx
                            .sendMessage(
                              id: widget.groupId!,
                              file: videoFile,
                              type: "reaction",
                              replyToId: widget.messageId,
                              onSendProgress: (sent, total) {
                                if (total != -1 &&
                                    widget.onReactionProgress != null) {
                                  widget.onReactionProgress!(
                                    tempId,
                                    sent / total,
                                  );
                                }
                              },
                            )
                            .then((success) {
                              if (widget.onReactionSuccess != null) {
                                widget.onReactionSuccess!(tempId, success);
                              }
                              if (success) {
                                log("Group reaction video sent successfully");
                              }
                            });
                      } else {
                        sendMessageRx
                            .sendMessage(
                              id: widget.userId!,
                              file: _pickFile,
                              type: "reaction",
                              replyToId: widget.messageId,
                            )
                            .then((success) {
                              if (success) {
                                log("Reaction video sent successfully");
                              }
                            });
                      }
                    }
                  }
                });
          } else {
            viewGroupFileRx
                .viewGroupFile(id: widget.messageId!)
                .waitingForSucess()
                .then((value) async {
                  if (value) {
                    // ✅ Update local state immediately
                    setState(() {
                      _isBlurred = false;
                    });

                    // ✅ Notify parent to update its state
                    widget.onUnblur();

                    final videoFile = await recordVideoSilently();
                    if (videoFile != null) {
                      setState(() {
                        _pickFile = videoFile;
                      });

                      final tempId = DateTime.now().millisecondsSinceEpoch;

                      if (widget.isGroup) {
                        if (widget.onReactionSend != null) {
                          widget.onReactionSend!(tempId, videoFile);
                        }
                        sendGroupMessageRx
                            .sendMessage(
                              id: widget.groupId!,
                              file: videoFile,
                              type: "reaction",
                              replyToId: widget.messageId,
                              onSendProgress: (sent, total) {
                                if (total != -1 &&
                                    widget.onReactionProgress != null) {
                                  widget.onReactionProgress!(
                                    tempId,
                                    sent / total,
                                  );
                                }
                              },
                            )
                            .then((success) {
                              if (widget.onReactionSuccess != null) {
                                widget.onReactionSuccess!(tempId, success);
                              }
                              if (success) {
                                log("Group reaction video sent successfully");
                              }
                            });
                      } else {
                        sendMessageRx
                            .sendMessage(
                              id: widget.userId!,
                              file: _pickFile,
                              type: "reaction",
                              replyToId: widget.messageId,
                            )
                            .then((success) {
                              if (success) {
                                log("Reaction video sent successfully");
                              }
                            });
                      }
                    }
                  }
                });
          }
        }
      },
      child: Container(
        padding: EdgeInsets.all(12.sp),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white30),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          spacing: 12.sp,
          children: [
            SvgPicture.asset(Assets.icons.appLogo),
            Text(
              "Click to view the media",
              style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
                fontSize: 12.sp,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
