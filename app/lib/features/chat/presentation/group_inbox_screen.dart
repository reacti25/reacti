import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/features/chat/model/group_inbox_response.dart';
import 'package:achiar_expert_app/features/chat/presentation/widget/receiver_message_widget.dart';
import 'package:achiar_expert_app/features/chat/presentation/widget/sender_message_widget.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common_widget/custom_network_image.dart';
import '../../../constants/app_constants.dart';
import '../../../helpers/di.dart';
import '../../../networks/api_access.dart';
import 'widget/send_message_widget.dart';

class GroupInboxScreen extends StatefulWidget {
  final int roomId;
  final String name;
  final String groupImage;
  const GroupInboxScreen({
    super.key,
    required this.roomId,
    required this.name,
    required this.groupImage,
  });

  @override
  State<GroupInboxScreen> createState() => _GroupInboxScreenState();
}

class _GroupInboxScreenState extends State<GroupInboxScreen> {
  final _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  PusherChannelsClient? client;
  StreamSubscription? connectionSubs;
  StreamSubscription<ChannelReadEvent>? somePrivateChannelEventSubs;
  late final String userToken;
  List<Message> cList = [];

  final ValueNotifier<XFile?> selectedImage = ValueNotifier<XFile?>(null);
  final ValueNotifier<String?> selectedMediaType = ValueNotifier<String?>(null);

  String? _replyMessage;
  String? _replyImage;
  String? _replyMediaType;
  int? _replyToId;
  ReplyTo? _replyToData;
  int? _highlightedMessageId;
  bool _showScrollToBottom = false;
  final Map<int, GlobalKey> _messageKeys = {};

  void _setReplyMessage(
    String text, {
    String? imageUrl,
    String? mediaType,
    int? replyToId,
    ReplyTo? replyToData,
  }) {
    setState(() {
      _replyMessage = text;
      _replyImage = imageUrl; // Store network image URL
      _replyMediaType = mediaType;
      _replyToId = replyToId;
      _replyToData = replyToData;
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      if (_scrollController.offset > 200 && !_showScrollToBottom) {
        setState(() {
          _showScrollToBottom = true;
        });
      } else if (_scrollController.offset <= 200 && _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  final ImagePicker _picker = ImagePicker();
  Future<void> pickGalleryImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      selectedImage.value = XFile(image.path);
      selectedMediaType.value = 'image';
    }
  }

  Future<void> pickCameraImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (image != null) {
      selectedImage.value = XFile(image.path);
      selectedMediaType.value = 'image';
    }
  }

  Future<void> pickGalleryVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      selectedImage.value = XFile(video.path);
      selectedMediaType.value = 'video';
    }
  }

  Future<void> pickCameraVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera);

      if (video != null) {
        selectedImage.value = XFile(video.path);
        selectedMediaType.value = 'video';
      }
    } catch (e) {
      log("Error picking camera video: $e");
    }
  }

  void _jumpToMessage(int messageId) {
    setState(() {
      _highlightedMessageId = messageId;
    });

    final key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      final index = cList.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _scrollController.animateTo(
          index * 150.0, // Estimate height
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }

    // Reset highlight after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _messageController.addListener(() {
      setState(() {});
    });
    userToken = appData.read(kKeyAccessToken);
    connect();
    // API Call g
    getGroupInboxRx.getGroupInboxMessage(id: widget.roomId);

    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    connectionSubs?.cancel();
    somePrivateChannelEventSubs?.cancel();
    client?.disconnect();
    cList.clear();
    super.dispose();
  }

  void connect() async {
    const hostOptions = PusherChannelsOptions.fromHost(
      scheme: 'wss',
      host: 'climbiq-goonclimbers.com',
      key: 'd3d9ba606e9065ff0c3d1d566ccf904c',
      shouldSupplyMetadataQueries: true,
      metadata: PusherChannelsOptionsMetadata.byDefault(),
      port: 8081,
    );
    client = PusherChannelsClient.websocket(
      options: hostOptions,
      connectionErrorHandler: (exception, trace, refresh) async {
        log("Connection error: $exception", error: trace);
        refresh();
      },
    );

    // log("Room id =====> ${widget.roomId}");
    log("User id =====> ${widget.roomId}");

    final myPrivateChannel = client!.privateChannel(
      "private-group-message.${appData.read(kKeyUserId)}",
      authorizationDelegate:
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
            authorizationEndpoint: Uri.parse(
              "https://reacti.io/api/broadcasting/auth",
            ),
            headers: {"Authorization": "Bearer $userToken"},
          ),
    );

    connectionSubs = client!.onConnectionEstablished.listen((_) {
      log('=============== Connected to server ===============');
      myPrivateChannel.subscribeIfNotUnsubscribed();
    });

    somePrivateChannelEventSubs = myPrivateChannel
        // .bind('App\\Events\\GroupMessageSentEvent')
        .bind('App\\Events\\GroupMessageSendEvent')
        .listen((event) {
          final messageData = json.decode(event.data);
          log("Received data ============>  $messageData");

          final newMessage = Message(
            id: messageData['message']['id'],
            senderId: messageData['message']['sender_id'],
            groupId: messageData['message']['group_id'],
            text: messageData['message']['text'],
            createdAt: messageData['message']['created_at'],
            file: messageData['message']['file'],
            isBlurred:
                (messageData['message']['is_blurred'] == true ||
                        messageData['message']['is_blurred'] == 1)
                    ? 1
                    : 0,
            mediaType: messageData['message']['media_type'],
            sender: Sender(
              id: messageData['message']['sender']['id'],
              firstName: messageData['message']['sender']['first_name'],
              lastName: messageData["message"]['sender']['last_name'],
              avatar: messageData['message']['sender']['avatar'],
            ),
            group: Group(
              id: messageData['message']['group']['id'],
              name: messageData['message']['group']['name'],
              avatar: messageData['message']['group']['avatar'],
            ),
            messageType: messageData['message']['message_type'],
            replyTo:
                messageData['message']['reply_to'] == null
                    ? null
                    : ReplyTo(
                      id: messageData['message']['reply_to']['id'],
                      senderId: messageData['message']['reply_to']['sender_id'],
                      text: messageData['message']['reply_to']['text'],
                      file: messageData['message']['reply_to']['file'],
                      mediaType:
                          messageData['message']['reply_to']['media_type'],
                      isBlurred:
                          messageData['message']['reply_to']['is_blurred'],
                      sender:
                          messageData['message']['reply_to']['sender'] == null
                              ? null
                              : Sender(
                                id:
                                    messageData['message']['reply_to']['sender']['id'],
                                firstName:
                                    messageData['message']['reply_to']['sender']['first_name'],
                                lastName:
                                    messageData['message']['reply_to']['sender']['last_name'],
                                avatar:
                                    messageData['message']['reply_to']['sender']['avatar'],
                              ),
                    ),
          );

          setState(() {
            // Find the optimistic local message if it exists
            final optimisticIndex = cList.indexWhere((msg) {
              // Match if it's explicitly local OR if it has a temporary ID (fast API response case)
              final isOptimistic =
                  msg.isLocal == true || (msg.id ?? 0) > 1000000000000;
              if (!isOptimistic) return false;

              if (msg.senderId != messageData['message']['sender_id']) {
                return false;
              }

              // Match by media type first (treating null and 'text' as same)
              final localMediaType = msg.mediaType ?? 'text';
              final serverMediaType =
                  messageData['message']['media_type'] ?? 'text';
              if (localMediaType != serverMediaType) {
                return false;
              }

              // If it's a text message, match text exactly (handle nulls)
              if (localMediaType == 'text') {
                return (msg.text ?? "").trim() ==
                    (messageData['message']['text'] ?? "").trim();
              }

              // For media messages, they might have optional text
              final localHasText = msg.text != null && msg.text!.isNotEmpty;
              final serverHasText =
                  messageData['message']['text'] != null &&
                  messageData['message']['text'] != "";

              if (localHasText && serverHasText) {
                return msg.text!.trim() ==
                    messageData['message']['text'].toString().trim();
              }

              // If neither has text, or only one has text, we consider it a match
              return true;
            });

            if (optimisticIndex != -1) {
              // Smoothly update the optimistic message with server data
              // We keep the localPath to act as a placeholder for the network image
              final localPath = cList[optimisticIndex].localPath;
              cList[optimisticIndex] = newMessage.copyWith(
                isLocal: false,
                localPath: localPath,
              );
            } else {
              cList.insert(0, newMessage);
            }
          });
        });

    client!.connect();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: () {
              groupDetailsRx
                  .getGroupDetails(id: widget.roomId)
                  .waitingForSucess()
                  .then((success) {
                    if (success) {
                      NavigationService.navigateToWithArgs(
                        Routes.groupDetailsRoute,
                        {'id': widget.roomId},
                      );
                    }
                  });
            },
            child: Row(
              spacing: 14.w,
              children: [
                ClipOval(
                  child: CustomNetworkImage(
                    width: 36.w,
                    height: 36.h,
                    urls: widget.groupImage,
                  ),
                ),
                Text(
                  widget.name,
                  style: TextFontStyle.headline16w500CFFFFFFPoppins,
                ),
              ],
            ),
          ),
          centerTitle: true,
        ),
        body: StreamBuilder(
          stream: getGroupInboxRx.getGroupInboxStream,
          builder: (context, asyncSnapshot) {
            if (asyncSnapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (asyncSnapshot.hasData) {
              GroupInboxResponse response = asyncSnapshot.data;
              if (cList.isEmpty) {
                cList = List.from(response.data!.messages!.reversed);
              }
              return InkWell(
                focusColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,

                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        shrinkWrap: true,
                        primary: false,
                        physics: BouncingScrollPhysics(),
                        itemCount: cList.length,
                        itemBuilder: (context, index) {
                          final data = cList[index];
                          return data.sender?.id == appData.read(kKeyUserId)
                              ? SenderMessageWidget(
                                key: _messageKeys.putIfAbsent(
                                  data.id ?? 0,
                                  () => GlobalKey(),
                                ),
                                message: data.text ?? "",
                                time: data.createdAt ?? "",
                                file: data.file ?? "",
                                mediaType: data.mediaType,
                                messageType: data.messageType,
                                messageId: data.id ?? 0,
                                onLongPressDelete: () {},
                                isLocal: data.isLocal == true,
                                localPath: data.localPath,
                                uploadProgress: data.uploadProgress,
                                isBlur: data.isBlurred,
                                isHighlighted: _highlightedMessageId == data.id,
                                onReply: () {
                                  _setReplyMessage(
                                    data.text ?? "",
                                    imageUrl: data.file,
                                    replyToId: data.id,
                                    replyToData: ReplyTo(
                                      id: data.id,
                                      senderId: data.senderId,
                                      text: data.text,
                                      file: data.file,
                                      mediaType: data.mediaType,
                                      isBlurred: data.isBlurred,
                                      sender: data.sender,
                                    ),
                                  );
                                },
                                replyTo: data.replyTo,
                                onTapReply: _jumpToMessage,
                              )
                              : ReceiverMessageWidget(
                                key: _messageKeys.putIfAbsent(
                                  data.id ?? 0,
                                  () => GlobalKey(),
                                ),
                                message: data.text ?? "",
                                avater: data.sender?.avatar ?? "",
                                time: data.createdAt ?? "",
                                file: data.file,
                                fileType: data.mediaType,
                                messageType: data.messageType,
                                isBlurred: data.isBlurred == 1 ? true : false,
                                messageId: data.id,
                                isHighlighted: _highlightedMessageId == data.id,
                                isGroup: true,
                                groupId: widget.roomId,
                                onReactionSend: (tempId, file) {
                                  final localMessage = Message(
                                    id: tempId,
                                    senderId: appData.read(kKeyUserId),
                                    groupId: widget.roomId,
                                    text: "",
                                    file: file.path,
                                    localPath: file.path,
                                    mediaType: "video",
                                    messageType: "reaction",
                                    isLocal: true,
                                    createdAt: "Just now",
                                    sender: Sender(
                                      id: appData.read(kKeyUserId),
                                      firstName: "Me",
                                    ),
                                    // replyTo: ReplyTo(
                                    //   id: data.id,
                                    //   senderId: data.senderId,
                                    //   text: data.text,
                                    //   file: data.file,
                                    //   mediaType: data.mediaType,
                                    //   sender: data.sender,
                                    // ),
                                  );
                                  setState(() {
                                    cList.insert(0, localMessage);
                                  });
                                },
                                onReactionProgress: (tempId, progress) {
                                  setState(() {
                                    final index = cList.indexWhere(
                                      (msg) => msg.id == tempId,
                                    );
                                    if (index != -1) {
                                      cList[index] = cList[index].copyWith(
                                        uploadProgress: progress,
                                      );
                                    }
                                  });
                                },
                                onReactionSuccess: (tempId, success) {
                                  if (success) {
                                    setState(() {
                                      final index = cList.indexWhere(
                                        (msg) => msg.id == tempId,
                                      );
                                      if (index != -1) {
                                        cList[index] = cList[index].copyWith(
                                          isLocal: false,
                                        );
                                      }
                                    });
                                  } else {
                                    setState(() {
                                      cList.removeWhere(
                                        (msg) => msg.id == tempId,
                                      );
                                    });
                                  }
                                },
                                // userId: widget.id,
                                onUnblur: () {
                                  setState(() {
                                    final messageIndex = cList.indexWhere(
                                      (item) => item.id == data.id,
                                    );
                                    if (messageIndex != -1) {
                                      cList[messageIndex].isBlurred = 0;
                                    }
                                  });
                                },
                                onReply: () {
                                  _setReplyMessage(
                                    data.text ?? "",
                                    imageUrl: data.file,
                                    replyToId: data.id,
                                    replyToData: ReplyTo(
                                      id: data.id,
                                      senderId: data.senderId,
                                      text: data.text,
                                      file: data.file,
                                      mediaType: data.mediaType,
                                      isBlurred: data.isBlurred,
                                      sender: data.sender,
                                    ),
                                  );
                                },
                                replyTo: data.replyTo,
                                onTapReply: _jumpToMessage,
                              );
                        },
                      ),
                    ),

                    // SendMessageWidget(
                    //   messageController: _messageController,
                    //   id: widget.roomId,
                    //   // file: selectedImage.value,
                    //   // image: selectedImage,
                    //   type: 'image',
                    //   onTapMedia: () {
                    //     // pickImage();
                    //   },
                    //   isGroup: true,
                    //   // image: ValueNotifier<List<AssetEntity>>([]),
                    // ),
                    if (_replyMessage != null || _replyImage != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            color: AppColors.cFFFFFF.withValues(alpha: 0.4),
                            width: double.maxFinite,
                            height: 0.5.h,
                          ),
                          UIHelper.verticalSpace(8.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Replying to: ${widget.name}',
                                        style: TextFontStyle
                                            .headline14w500CFFFFFFPoppins
                                            .copyWith(
                                              fontSize: 13.5.sp,
                                              color: AppColors.cFFFFFF
                                                  .withValues(alpha: 0.9),
                                            ),
                                      ),
                                      UIHelper.verticalSpace(2.h),
                                      // Show text reply if exists
                                      if (_replyMessage != null)
                                        Text(
                                          _replyMessage!,
                                          style: TextFontStyle
                                              .headline14w400C666666Poppins
                                              .copyWith(
                                                color: AppColors.cFFFFFF,
                                                fontSize: 13.sp,
                                              ),
                                        ),
                                      // Show image reply if exists
                                      if (_replyImage != null)
                                        Text(
                                          'Replying to ${_replyMediaType ?? 'image'}',
                                          style: TextFontStyle
                                              .headline14w400C666666Poppins
                                              .copyWith(
                                                color: AppColors.cFFFFFF,
                                                fontSize: 13.sp,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),

                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _replyMessage = null;
                                      _replyImage = null;
                                      _replyMediaType = null;
                                      _replyToId = null;
                                      _replyToData = null;
                                    });
                                  },
                                  child: Icon(
                                    Icons.close,
                                    color: AppColors.cFFFFFF.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    SendMessageWidget(
                      messageController: _messageController,
                      id: widget.roomId,
                      file: selectedImage.value,
                      image: selectedImage,
                      mediaType: selectedMediaType,
                      replyToId: _replyToId,
                      type: 'image',
                      onTapMedia: () {
                        _imagePickerDialog(context);
                      },
                      isGroup: true,
                      onSend: (text, file, mediaType, tempId) {
                        final localMessage = Message(
                          id: tempId,
                          senderId: appData.read(kKeyUserId),
                          groupId: widget.roomId,
                          text: text,
                          file: file?.path,
                          localPath: file?.path,
                          mediaType: mediaType,
                          isLocal: true,
                          createdAt: "Just now",
                          sender: Sender(
                            id: appData.read(kKeyUserId),
                            firstName: "Me",
                          ),
                          replyTo: _replyToData,
                        );
                        setState(() {
                          cList.insert(0, localMessage);
                          _replyMessage = null;
                          _replyImage = null;
                          _replyToId = null;
                          _replyToData = null;
                        });
                      },
                      onProgress: (tempId, progress) {
                        setState(() {
                          final index = cList.indexWhere(
                            (msg) => msg.id == tempId,
                          );
                          if (index != -1) {
                            cList[index] = cList[index].copyWith(
                              uploadProgress: progress,
                            );
                          }
                        });
                      },
                      onSuccess: (tempId, success) {
                        if (success) {
                          setState(() {
                            final index = cList.indexWhere(
                              (msg) => msg.id == tempId,
                            );
                            if (index != -1) {
                              cList[index] = cList[index].copyWith(
                                isLocal: false,
                              );
                            }
                          });
                        } else {
                          setState(() {
                            cList.removeWhere((msg) => msg.id == tempId);
                          });
                        }
                      },
                    ),
                  ],
                ),
              );
            } else {
              return SizedBox.shrink();
            }
          },
        ),
        floatingActionButton:
            _showScrollToBottom
                ? Padding(
                  padding: EdgeInsets.only(bottom: 70.h),
                  child: FloatingActionButton.small(
                    onPressed: _scrollToBottom,
                    backgroundColor: AppColors.allPrimaryColor,
                    child: const Icon(
                      Icons.arrow_downward,
                      color: Colors.black,
                    ),
                  ),
                )
                : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Future<dynamic> _imagePickerDialog(BuildContext context) {
    return showModalBottomSheet(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      context: context,
      builder:
          (_) => Container(
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
                GestureDetector(
                  onTap: () {
                    NavigationService.goBack;
                    pickGalleryImage();
                  },
                  child: Text(
                    "Pick Image from Gallery",
                    style: TextFontStyle.headline16w400CFFFFFFPoppins,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    NavigationService.goBack;
                    pickCameraImage();
                  },
                  child: Text(
                    "Pick Image from Camera",
                    style: TextFontStyle.headline16w400CFFFFFFPoppins,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    NavigationService.goBack;
                    pickGalleryVideo();
                  },
                  child: Text(
                    "Pick Video from Gallery",
                    style: TextFontStyle.headline16w400CFFFFFFPoppins,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    NavigationService.goBack;
                    pickCameraVideo();
                  },
                  child: Text(
                    "Pick Video from Camera",
                    style: TextFontStyle.headline16w400CFFFFFFPoppins,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
