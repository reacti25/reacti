import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/features/chat/data/chat_realtime_service.dart';
import 'package:achiar_expert_app/features/chat/logic/message_reconciler.dart';
import 'package:achiar_expert_app/features/chat/model/group_inbox_response.dart';
import 'package:achiar_expert_app/features/chat/presentation/widget/receiver_message_widget.dart';
import 'package:achiar_expert_app/features/chat/presentation/widget/sender_message_widget.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../constants/app_constants.dart';
import '../../../helpers/di.dart';
import '../../../networks/api_access.dart';
import 'widget/chat_app_bar_title.dart';
import 'widget/chat_reply_banner.dart';
import 'widget/media_picker_sheet.dart';
import 'widget/scroll_to_bottom_button.dart';
import 'widget/send_message_widget.dart';

/// Full-screen group conversation view.
///
/// Shows the message thread for a group, the composer ([SendMessageWidget])
/// and supports the reaction flow on received media. Subscribes to the
/// user's group-message Pusher channel so incoming messages append in
/// realtime and reconciles optimistic local messages with their
/// server-confirmed counterparts. Opened by [ChatScreen] for group rows.
class GroupInboxScreen extends StatefulWidget {
  /// Identifier of the group room, used for the API and realtime channel.
  final int roomId;

  /// Display name of the group, shown in the app bar.
  final String name;

  /// Avatar image URL of the group.
  final String groupImage;

  /// Creates the group inbox screen.
  const GroupInboxScreen({
    super.key,
    required this.roomId,
    required this.name,
    required this.groupImage,
  });

  /// Creates the mutable state managing the thread and realtime connection.
  @override
  State<GroupInboxScreen> createState() => _GroupInboxScreenState();
}

/// State for [GroupInboxScreen]; owns the message list, the Pusher
/// connection, media selection and the reply/highlight state.
class _GroupInboxScreenState extends State<GroupInboxScreen> {
  /// Controller backing the composer's text field.
  final _messageController = TextEditingController();

  /// Scroll controller for the (reversed) message list.
  final ScrollController _scrollController = ScrollController();

  /// Owns the Pusher realtime connection for this screen.
  final ChatRealtimeService _realtime = ChatRealtimeService();

  /// The current user's access token, used to authorize the private channel.
  late final String userToken;

  /// Local, mutable copy of the group messages, newest-first.
  List<Message> cList = [];

  /// The attachment currently staged for sending.
  final ValueNotifier<XFile?> selectedImage = ValueNotifier<XFile?>(null);

  /// The media kind (`image`/`video`) of the staged attachment.
  final ValueNotifier<String?> selectedMediaType = ValueNotifier<String?>(null);

  /// Text of the message being replied to, shown in the reply banner.
  String? _replyMessage;

  /// Media URL of the message being replied to.
  String? _replyImage;

  /// Media kind of the message being replied to.
  String? _replyMediaType;

  /// Identifier of the message being replied to.
  int? _replyToId;

  /// Full quoted-message model attached to the outgoing reply.
  ReplyTo? _replyToData;

  /// Identifier of the message currently highlighted after a reply jump.
  int? _highlightedMessageId;

  /// Whether the scroll-to-bottom button should be shown.
  bool _showScrollToBottom = false;

  /// Per-message [GlobalKey]s used to scroll a message into view on a reply
  /// jump.
  final Map<int, GlobalKey> _messageKeys = {};

  /// Stages a reply to a message, recording its [text], optional [imageUrl]
  /// and [mediaType], the [replyToId] and the full [replyToData] model, then
  /// rebuilds to show the reply banner.
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

  /// Toggles [_showScrollToBottom] based on how far the list is scrolled.
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

  /// Animates the (reversed) list back to the newest message.
  void _scrollToBottom() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Picker used to select images and videos for sending.
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the gallery and stages it as the attachment.
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

  /// Captures an image from the camera and stages it as the attachment.
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

  /// Picks a video from the gallery and stages it as the attachment.
  Future<void> pickGalleryVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      selectedImage.value = XFile(video.path);
      selectedMediaType.value = 'video';
    }
  }

  /// Records a video with the camera and stages it as the attachment,
  /// logging the error if recording fails.
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

  /// Scrolls the message identified by [messageId] into view and briefly
  /// highlights it.
  ///
  /// Prefers the message's registered [GlobalKey]; if that is not laid out
  /// it falls back to an estimated offset. The highlight is cleared after
  /// two seconds.
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

  /// Wires up the composer listener, reads the auth token, opens the Pusher
  /// connection, loads the group conversation and attaches the scroll
  /// listener.
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

  /// Detaches listeners, cancels the Pusher subscriptions, disconnects the
  /// client and clears the cached message list.
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _realtime.dispose();
    cList.clear();
    super.dispose();
  }

  /// Opens the Pusher websocket connection and subscribes to the user's
  /// private group-message channel.
  ///
  /// Each `GroupMessageSendEvent` is decoded into a [Message]; if it matches
  /// an outstanding optimistic local message that entry is reconciled in
  /// place (keeping its local file as a placeholder), otherwise the message
  /// is inserted at the head of the list.
  void connect() async {
    _realtime.connect(
      authToken: userToken,
      subscriptions: [
        ChatChannelSubscription(
          channelName: "private-group-message.${appData.read(kKeyUserId)}",
          eventName: 'App\\Events\\GroupMessageSendEvent',
        ),
      ],
      onEvent: (event) {
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
            // Merge the incoming server message into the local list,
            // reconciling any optimistic entry. See `reconcileGroupMessage`.
            cList = reconcileGroupMessage(cList, newMessage);
          });
      },
    );
  }

  /// Builds the group conversation screen: an app bar that opens group
  /// details, a stream-driven message list, the reply banner, the composer
  /// and a scroll-to-bottom button.
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
            child: ChatAppBarTitle(
              name: widget.name,
              imageUrl: widget.groupImage,
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
                      ChatReplyBanner(
                        chatName: widget.name,
                        replyMessage: _replyMessage,
                        replyImage: _replyImage,
                        replyMediaType: _replyMediaType,
                        onClose: () {
                          setState(() {
                            _replyMessage = null;
                            _replyImage = null;
                            _replyMediaType = null;
                            _replyToId = null;
                            _replyToData = null;
                          });
                        },
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
                ? ScrollToBottomButton(onPressed: _scrollToBottom)
                : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  /// Shows the bottom sheet offering image/video selection from gallery or
  /// camera, each option delegating to the matching picker method.
  Future<dynamic> _imagePickerDialog(BuildContext context) {
    return showModalBottomSheet(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      context: context,
      builder:
          (_) => MediaPickerSheet(
            onPickGalleryImage: () {
              NavigationService.goBack;
              pickGalleryImage();
            },
            onPickCameraImage: () {
              NavigationService.goBack;
              pickCameraImage();
            },
            onPickGalleryVideo: () {
              NavigationService.goBack;
              pickGalleryVideo();
            },
            onPickCameraVideo: () {
              NavigationService.goBack;
              pickCameraVideo();
            },
          ),
    );
  }
}
