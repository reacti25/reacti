import 'dart:developer';
import 'dart:io';

import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../helpers/ui_helpers.dart';
import '../../../../networks/api_access.dart';

class SendMessageWidget extends StatefulWidget {
  const SendMessageWidget({
    super.key,
    required this.id,
    required this.messageController,
    this.blockSendWhenViolated = false,
    this.file,
    this.onTapMedia,
    this.type,
    this.image,
    this.mediaType,
    this.replyToId,
    required this.isGroup,
    this.onSend,
    this.onProgress,
    this.onSuccess,
  });

  final XFile? file;
  final int id;
  final TextEditingController messageController;
  final bool blockSendWhenViolated;
  final VoidCallback? onTapMedia;
  final String? type;
  final ValueNotifier<XFile?>? image;
  final ValueNotifier<String?>? mediaType;
  final int? replyToId;
  final bool isGroup;
  final Function(String text, XFile? file, String mediaType, int tempId)?
  onSend;
  final Function(int tempId, double progress)? onProgress;
  final Function(int tempId, bool success)? onSuccess;

  @override
  State<SendMessageWidget> createState() => _SendMessageWidgetState();
}

class _SendMessageWidgetState extends State<SendMessageWidget> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 16.h,
        left: 16.w,
        right: 16.w,
        top: 12.h,
      ),
      child: Column(
        spacing: 4.h,
        children: [
          if (widget.image != null)
            ValueListenableBuilder<XFile?>(
              valueListenable: widget.image!,
              builder: (context, file, _) {
                return file != null
                    ? Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 100.h,
                        width: 100.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child:
                                  widget.mediaType?.value == 'video'
                                      ? Container(
                                        height: 150.h,
                                        width: 150.w,
                                        color: Colors.black87,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.video_collection,
                                              color: Colors.white,
                                              size: 30.sp,
                                            ),
                                            UIHelper.verticalSpace(4.h),
                                            Text(
                                              "Video",
                                              style:
                                                  TextFontStyle
                                                      .headline12w400CFFFFFFPoppins,
                                            ),
                                          ],
                                        ),
                                      )
                                      : Image.file(
                                        height: 150.h,
                                        width: 150.w,
                                        File(widget.image!.value!.path),
                                        fit: BoxFit.cover,
                                      ),
                            ),
                            Positioned(
                              right: 6.w,
                              top: 6.h,
                              child: GestureDetector(
                                onTap: () {
                                  widget.image!.value = null;
                                  widget.mediaType?.value = null;
                                },
                                child: Container(
                                  padding: EdgeInsets.all(2.sp),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white54,
                                  ),
                                  child: Icon(Icons.close_rounded, size: 16.sp),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : SizedBox.shrink();
              },
            ),
          Row(
            spacing: 8.w,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: GestureDetector(
                  onTap: widget.onTapMedia,
                  child: Container(
                    padding: EdgeInsets.all(12.sp),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.c333333,
                    ),
                    child: SvgPicture.asset(
                      Assets.icons.attachmentIcon,
                      width: 16.w,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: widget.messageController,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    hintText: "Type a message...",
                    hintStyle: TextFontStyle.headline16w400CFFFFFFPoppins
                        .copyWith(fontSize: 14.sp),
                    // filled: true,
                    // fillColor: AppColors.cFFFFFF,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18.r),
                      borderSide: BorderSide(color: AppColors.cFFFFFF),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18.r),
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18.r),
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: TextFontStyle.headline14w500CFFFFFFPoppins,
                ),
              ),
              InkWell(
                onTap: () {
                  final messageText = widget.messageController.text.trim();
                  final messageFile = widget.image?.value;
                  final mediaType = widget.mediaType?.value ?? 'text';

                  if (messageText.isEmpty && messageFile == null) {
                    return; // Prevent sending if the message is empty
                  }

                  final tempId = DateTime.now().millisecondsSinceEpoch;

                  if (widget.onSend != null) {
                    widget.onSend!(messageText, messageFile, mediaType, tempId);
                  }

                  widget.messageController.clear();
                  if (widget.image != null) widget.image!.value = null;
                  if (widget.mediaType != null) widget.mediaType!.value = null;

                  if (widget.isGroup) {
                    log("Message is =========> $messageText");
                    // Send group message
                    if (widget.replyToId != null) {
                      log("This is reply with id ${widget.replyToId}");
                    } else {
                      log("This is not a reply");
                    }
                    sendGroupMessageRx
                        .sendMessage(
                          id: widget.id,
                          message: messageText,
                          file: messageFile,
                          type: "normal",
                          replyToId: widget.replyToId,
                          onSendProgress: (sent, total) {
                            if (total != -1) {
                              final progress = sent / total;
                              if (widget.onProgress != null) {
                                widget.onProgress!(tempId, progress);
                              }
                            }
                          },
                        )
                        .then((success) {
                          if (widget.onSuccess != null) {
                            widget.onSuccess!(tempId, success);
                          }
                          if (success) {
                            getAllChatRx.getAllChat();
                          }
                        });
                    return;
                  }
                  sendMessageRx
                      .sendMessage(
                        id: widget.id,
                        message: messageText,
                        file: messageFile,
                        type: "normal",
                        replyToId: widget.replyToId,
                        onSendProgress: (sent, total) {
                          if (total != -1) {
                            final progress = sent / total;
                            if (widget.onProgress != null) {
                              widget.onProgress!(tempId, progress);
                            }
                          }
                        },
                      )
                      .then((success) {
                        if (widget.onSuccess != null) {
                          widget.onSuccess!(tempId, success);
                        }
                        if (success) {
                          getAllChatRx.getAllChat();
                        }
                      });
                },
                child: Container(
                  padding: EdgeInsets.all(12.sp),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.c333333,
                  ),
                  child: SvgPicture.asset(Assets.icons.sendIcon, width: 16.w),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
