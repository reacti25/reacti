import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/features/chat/presentation/widget/sender_message_widget.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/toast.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:achiar_expert_app/networks/api_access.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common_widget/custom_network_image.dart';
import '../../../constants/app_constants.dart';
import '../../../helpers/di.dart';
import '../../../helpers/video_controller_cache.dart';
import '../model/inbox_response.dart';
import 'widget/receiver_message_widget.dart';
import 'widget/send_message_widget.dart';

/// Full-screen one-to-one conversation view.
///
/// Shows the message thread for a single peer, the composer
/// ([SendMessageWidget]) and block/report controls. Subscribes to the
/// room's Pusher channel so incoming messages append in realtime, reconciles
/// optimistic local messages with their server-confirmed counterparts, and
/// supports swipe-to-reply, reply jumps and message deletion. Opened by
/// [ChatScreen] for non-group conversations.
class InboxScreen extends StatefulWidget {
  /// Identifier of the peer user this conversation is with.
  final int id;

  /// Identifier of the chat room, used to subscribe to the realtime channel.
  final int roomId;

  /// Display name of the peer, shown in the app bar.
  final String name;

  /// Avatar image URL of the peer.
  final String image;

  /// Creates the one-to-one inbox screen.
  const InboxScreen({
    super.key,
    required this.id,
    required this.roomId,
    required this.name,
    required this.image,
  });

  /// Creates the mutable state managing the thread and realtime connection.
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

/// State for [InboxScreen]; owns the message list, the Pusher connection,
/// media selection and the reply/highlight state.
class _InboxScreenState extends State<InboxScreen> {
  /// Controller backing the composer's text field.
  final _messageController = TextEditingController();

  /// Scroll controller for the (reversed) message list.
  final _scrollController = ScrollController();

  /// The Pusher websocket client, created in [connect].
  PusherChannelsClient? client;

  /// Subscription to the Pusher connection-established stream.
  StreamSubscription? connectionSubs;

  /// Subscription to the room's message-send channel events.
  StreamSubscription<ChannelReadEvent>? somePrivateChannelEventSubs;

  /// The current user's access token, used to authorize the private channel.
  late final String userToken;

  /// Local, mutable copy of the conversation messages, newest-first.
  List<Chat> cList = [];

  // XFile? _recordedFile;

  /// Picker used to select images and videos for sending.
  final ImagePicker _picker = ImagePicker();

  // ValueNotifier to store selected image
  /// The attachment currently staged for sending.
  final ValueNotifier<XFile?> selectedImage = ValueNotifier<XFile?>(null);

  /// The media kind (`image`/`video`) of the staged attachment.
  final ValueNotifier<String?> selectedMediaType = ValueNotifier<String?>(null);

  /// Whether the scroll-to-bottom button should be shown.
  bool _showScrollToBottom = false;

  /// Per-message [GlobalKey]s used to scroll a message into view on a reply
  /// jump.
  final Map<int, GlobalKey> _messageKeys = {};

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
  /// surfacing a toast if recording fails.
  Future<void> pickCameraVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera);

      if (video != null) {
        selectedImage.value = XFile(video.path);
        selectedMediaType.value = 'video';
      }
    } catch (e) {
      log("Error picking camera video: $e");
      ToastUtil.showErrorMessage("Recording failed: $e");
    }
  }

  /// Wires up the composer listener, reads the auth token, opens the Pusher
  /// connection, loads the conversation and attaches the scroll listener.
  @override
  void initState() {
    super.initState();

    _messageController.addListener(() {
      setState(() {});
    });
    userToken = appData.read(kKeyAccessToken);
    connect();
    // API Call Must
    getInboxMessageRx.getInboxMessage(id: widget.id);

    _scrollController.addListener(_scrollListener);
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

  /// Detaches listeners, cancels the Pusher subscriptions, disconnects the
  /// client and clears the cached message list.
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageController.dispose();
    connectionSubs?.cancel();
    somePrivateChannelEventSubs?.cancel();
    client?.disconnect();
    cList.clear();
    // VideoControllerCache.clear(); // Keep cache alive for performance
    super.dispose();
  }

  /// Opens the Pusher websocket connection and subscribes to this room's
  /// private channel.
  ///
  /// Each `MessageSendEvent` is decoded into a [Chat]; if it matches an
  /// outstanding optimistic local message that entry is reconciled in place
  /// (keeping its local file as a placeholder), otherwise the message is
  /// inserted at the head of the list.
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
    // log("Room id =====> ${widget.roomId}");

    final myPrivateChannel = client!.privateChannel(
      "private-chat-room.${widget.roomId}",
      // "private-chat-sender.${appData.read(kKeyUserId)}",
      authorizationDelegate:
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
            authorizationEndpoint: Uri.parse(
              "https://reacti.io/api/broadcasting/auth",
            ),
            headers: {"Authorization": "Bearer $userToken"},
          ),
    );

    connectionSubs = client!.onConnectionEstablished.listen((_) {
      log('==========Connected to server==========');
      myPrivateChannel.subscribeIfNotUnsubscribed();
    });

    somePrivateChannelEventSubs = myPrivateChannel.bind('App\\Events\\MessageSendEvent').listen((
      event,
    ) {
      final messageData = json.decode(event.data);
      log("Received data =======> $messageData");

      log("Media Type =============> ${messageData['chat']['media_type']}");
      log("Is Blur Media =============> ${messageData['chat']['is_blurred']}");

      final newMessage = Chat(
        id: messageData['chat']['id'],
        senderId: messageData['chat']['sender_id'],
        receiverId: messageData['chat']['receiver_id'],
        text: messageData['chat']['text'],
        file: messageData['chat']['file'],
        humanizeDate: messageData['chat']['humanize_date'],
        isBlurred:
            (messageData['chat']['is_blurred'] == true ||
                    messageData['chat']['is_blurred'] == 1)
                ? 1
                : 0,
        mediaType: messageData['chat']['media_type'],
        sender: Receiver(
          id: messageData['chat']['sender']['id'],
          firstName: messageData['chat']['sender']['first_name'],
          lastName: messageData["chat"]['sender']['last_name'],
          avatar: messageData['chat']['sender']['avatar'],
        ),

        receiver: Receiver(
          id: messageData['chat']['receiver']['id'],
          firstName: messageData['chat']['receiver']['first_name'],
          lastName: messageData["chat"]['receiver']['last_name'],
          avatar: messageData['chat']['receiver']['avatar'],
        ),
        replyTo:
            messageData['chat']['reply_to'] == null
                ? null
                : ReplyTo(
                  id: messageData['chat']['reply_to']['id'],
                  senderId: messageData['chat']['reply_to']['sender_id'],
                  text: messageData['chat']['reply_to']['text'],
                  file: messageData['chat']['reply_to']['file'],
                  mediaType: messageData['chat']['reply_to']['media_type'],
                  isBlurred: messageData['chat']['reply_to']['is_blurred'],
                  sender:
                      messageData['chat']['reply_to']['sender'] == null
                          ? null
                          : Receiver(
                            id: messageData['chat']['reply_to']['sender']['id'],
                            firstName:
                                messageData['chat']['reply_to']['sender']['first_name'],
                            lastName:
                                messageData['chat']['reply_to']['sender']['last_name'],
                            avatar:
                                messageData['chat']['reply_to']['sender']['avatar'],
                          ),
                ),
      );

      setState(() {
        // Find the optimistic local message if it exists
        final optimisticIndex = cList.indexWhere((chat) {
          // Match if it's explicitly local OR if it has a temporary ID (fast API response case)
          final isOptimistic =
              chat.isLocal == true || (chat.id ?? 0) > 1000000000000;
          if (!isOptimistic) return false;

          if (chat.senderId != messageData['chat']['sender_id']) {
            return false;
          }

          // Match by media type first (treating null and 'text' as same)
          final localMediaType = chat.mediaType ?? 'text';
          final serverMediaType = messageData['chat']['media_type'] ?? 'text';
          if (localMediaType != serverMediaType) {
            return false;
          }

          // If it's a text message, match text exactly (handle nulls)
          if (localMediaType == 'text') {
            return (chat.text ?? "").trim() ==
                (messageData['chat']['text'] ?? "").trim();
          }

          // For media messages, they might have optional text
          final localHasText = chat.text != null && chat.text!.isNotEmpty;
          final serverHasText =
              messageData['chat']['text'] != null &&
              messageData['chat']['text'] != "";

          if (localHasText && serverHasText) {
            return chat.text!.trim() ==
                messageData['chat']['text'].toString().trim();
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
            replyTo: newMessage.replyTo ?? cList[optimisticIndex].replyTo,
          );
        } else {
          cList.insert(0, newMessage);
        }
      });
    });

    client!.connect();
  }

  /// Builds the conversation screen: an app bar with the peer and
  /// block/report menu, a stream-driven message list, the reply banner, the
  /// composer or block widgets, and a scroll-to-bottom button.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          spacing: 14.w,
          children: [
            ClipOval(
              child: CustomNetworkImage(
                width: 36.w,
                height: 36.h,
                urls: widget.image,
              ),
            ),
            Text(
              widget.name,
              style: TextFontStyle.headline16w500CFFFFFFPoppins,
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (getInboxMessageRx.isBlocked == false)
            StreamBuilder(
              stream: getInboxMessageRx.getInboxStream,
              builder: (context, asyncSnapshot) {
                if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox.shrink();
                } else if (asyncSnapshot.hasData) {
                  InboxResponse response = asyncSnapshot.data;
                  return response.data?.isBlocked == true
                      ? SizedBox.shrink()
                      : BlockAndReportWidget(widget: widget);
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
        ],
      ),
      body: StreamBuilder(
        stream: getInboxMessageRx.getInboxStream,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (asyncSnapshot.hasData) {
            InboxResponse response = asyncSnapshot.data;
            if (cList.isEmpty) {
              cList = List.from(response.data!.chat!.reversed);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _precacheMedia();
              });
            }
            return InkWell(
              focusColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              hoverColor: Colors.transparent,
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        shrinkWrap: true,
                        primary: false,
                        physics: const BouncingScrollPhysics(),
                        itemCount: cList.length,
                        itemBuilder: (context, index) {
                          final data = cList[index];
                          return data.sender?.id == appData.read(kKeyUserId)
                              ? SenderMessageWidget(
                                key: _messageKeys.putIfAbsent(
                                  data.id ?? 0,
                                  () => GlobalKey(),
                                ),
                                isBlur: data.isBlurred,
                                message: data.text ?? "",
                                time: data.humanizeDate ?? "",
                                file: data.file ?? "",
                                mediaType: data.mediaType ?? "",
                                isBlocked: response.data?.isBlocked,
                                messageId: data.id!,
                                receiverId: widget.id,
                                isLocal: data.isLocal == true,
                                localPath: data.localPath,
                                uploadProgress: data.uploadProgress,
                                isHighlighted: _highlightedMessageId == data.id,
                                onLongPressDelete: () {
                                  _deleteMessageDialog(context, data, index);
                                },
                                onReply: () {
                                  _setReplyMessage(
                                    data.text ?? "",
                                    imageUrl: data.file,
                                    mediaType: data.mediaType,
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
                                avater: data.receiver?.avatar ?? "",
                                time: data.humanizeDate ?? "",
                                file: data.file,
                                fileType: data.mediaType,
                                isBlurred: data.isBlurred == 1 ? true : false,
                                isHighlighted: _highlightedMessageId == data.id,
                                messageId: data.id,
                                userId: widget.id,
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
                                  // When a message is long pressed, set it as the reply message
                                  // setState(() {
                                  //   _replyMessage =
                                  //       data.text; // Store the message for replying
                                  // });

                                  _setReplyMessage(
                                    data.text ?? "",
                                    imageUrl: data.file,
                                    mediaType: data.mediaType,
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
                    if (response.data?.isBlocked == false)
                      SendMessageWidget(
                        messageController: _messageController,
                        id: widget.id,
                        file: selectedImage.value,
                        image: selectedImage,
                        mediaType: selectedMediaType,
                        replyToId: _replyToId,
                        onProgress: (tempId, progress) {
                          setState(() {
                            final index = cList.indexWhere(
                              (chat) => chat.id == tempId,
                            );
                            if (index != -1) {
                              cList[index].uploadProgress = progress;
                            }
                          });
                        },
                        onSend: (text, file, mediaType, tempId) {
                          final localMessage = Chat(
                            id: tempId,
                            senderId: appData.read(kKeyUserId),
                            receiverId: widget.id,
                            text: text,
                            file: file?.path,
                            localPath: file?.path,
                            mediaType: mediaType,
                            isLocal: true,
                            humanizeDate: "Just now",
                            sender: Receiver(
                              id: appData.read(kKeyUserId),
                              firstName: "Me",
                            ),
                            replyTo: _replyToData,
                          );
                          setState(() {
                            cList.insert(0, localMessage);
                            _replyMessage = null;
                            _replyImage = null;
                            _replyMediaType = null;
                            _replyToId = null;
                            _replyToData = null;
                          });
                        },
                        onSuccess: (tempId, success) {
                          if (success) {
                            setState(() {
                              final index = cList.indexWhere(
                                (chat) => chat.id == tempId,
                              );
                              if (index != -1) {
                                cList[index] = cList[index].copyWith(
                                  isLocal: false,
                                );
                              }
                            });
                          } else {
                            // If sending failed, remove the optimistic message
                            setState(() {
                              cList.removeWhere((chat) => chat.id == tempId);
                            });
                          }
                        },
                        type: 'image',
                        onTapMedia: () {
                          _imagePickerDialog(context);
                        },
                        isGroup: false,
                        // image: ValueNotifier<List<AssetEntity>>([]),
                      ),

                    if (response.data?.isBlocked == true &&
                        response.data?.blockByMe == true)
                      _isBlockWidget(),
                    if (response.data?.isBlocked == true &&
                        response.data?.blockByMe != true)
                      amIBlockedWidget(),
                  ],
                ),
              ),
            );
          } else {
            return const SizedBox.shrink();
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
                  child: const Icon(Icons.arrow_downward, color: Colors.black),
                ),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
          (_) => Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 26.h),
            decoration: BoxDecoration(
              color: Color(0xFF242424),
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

  /// Builds the notice shown when the current user has been blocked by the
  /// peer and can no longer send messages.
  Container amIBlockedWidget() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
      width: double.maxFinite,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cFFFFFF.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(44.r),
      ),
      child: Text(
        "You can not send any message to this user. You have been blocked.",
        style: TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
          fontWeight: FontWeight.w300,
          color: AppColors.cFFFFFF.withValues(alpha: 0.6),
          fontSize: 12.sp,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Builds the "Unblock" button shown when the current user has blocked the
  /// peer; tapping it unblocks them and reloads the conversation.
  Widget _isBlockWidget() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: CustomButton(
        onTap: () {
          blockUserRx.blockUser(id: widget.id).waitingForSucess().then((
            success,
          ) {
            if (success) {
              ToastUtil.showSuccessMessage("User unblocked successfully");
              getInboxMessageRx.getInboxMessage(id: widget.id);
            }
          });
        },
        btnName: "Unblock",
      ),
    );
  }

  /// Warms the media caches for the ten most recent messages — images via
  /// [precacheImage] and videos via [VideoControllerCache.precacheVideos] —
  /// so they render instantly when scrolled into view.
  void _precacheMedia() {
    if (cList.isEmpty) return;

    // Pre-cache the latest 10 messages
    final latestMessages = cList.take(10).toList();

    List<String> videoUrls = [];
    for (var chat in latestMessages) {
      if (chat.file != null && chat.file!.isNotEmpty) {
        if (chat.mediaType == 'video') {
          videoUrls.add(chat.file!);
        } else if (chat.mediaType == 'image') {
          precacheImage(CachedNetworkImageProvider(chat.file!), context);
        }
      }
    }

    if (videoUrls.isNotEmpty) {
      VideoControllerCache.precacheVideos(videoUrls);
    }
  }

  /// Shows the bottom sheet confirming deletion of [data] (the message at
  /// [index]); on confirmation it calls the delete API, removes the row and
  /// reloads the conversation.
  Future<dynamic> _deleteMessageDialog(
    BuildContext context,
    Chat data,
    int index,
  ) {
    return showModalBottomSheet(
      context: context,
      builder:
          (_) => Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            child: InkWell(
              onTap: () {
                log("Delete Conversation");

                deleteMessageRx
                    .deleteMessage(messageId: data.id!)
                    .waitingForSucess()
                    .then((success) {
                      cList.removeAt(index);
                      getInboxMessageRx.getInboxMessage(id: widget.id);
                    });
                Navigator.pop(context);
              },
              child: Row(
                spacing: 12.w,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 20.sp),
                  Text(
                    "Delete this message",
                    style: TextFontStyle.headline16w500C333333Poppins.copyWith(
                      color: AppColors.c000000,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

/// App-bar overflow menu for an [InboxScreen] offering "Block" and "Report"
/// actions against the conversation peer.
class BlockAndReportWidget extends StatelessWidget {
  /// Creates the block/report menu for the given [widget] inbox screen.
  const BlockAndReportWidget({super.key, required this.widget});

  /// The inbox screen this menu acts upon, providing the peer id and name.
  final InboxScreen widget;

  /// Builds the popup menu; selecting "block" blocks the peer and reloads the
  /// conversation, while "report" navigates to the report-user route.
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      onSelected: (value) {
        if (value == 'block') {
          blockUserRx.blockUser(id: widget.id).waitingForSucess().then((
            success,
          ) {
            if (success) {
              ToastUtil.showSuccessMessage("User blocked successfully");
              getInboxMessageRx.getInboxMessage(id: widget.id);
            }
          });
        } else {
          NavigationService.navigateToWithArgs(Routes.reportUserRoute, {
            'name': widget.name,
          });
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: 'block',
            child: Row(
              children: [
                // const Icon(Icons.delete_outline),
                // UIHelper.horizontalSpace(16.w),
                Text(
                  "Block This User",
                  style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
                    color: AppColors.c000000,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                // const Icon(Icons.delete_outline),
                // UIHelper.horizontalSpace(16.w),
                Text(
                  "Report This User",
                  style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
                    color: AppColors.c000000,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}
