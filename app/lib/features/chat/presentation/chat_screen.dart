import 'dart:async';
import 'dart:developer';

import 'package:achiar_expert_app/common_widget/custom_network_image.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/features/chat/model/chat_list_response.dart';
import 'package:achiar_expert_app/features/profile/model/profile_response.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/networks/api_access.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constants/app_constants.dart';
import '../../../helpers/di.dart';
import '../logic/chat_list_logic.dart';

/// Top-level conversations screen listing every chat and group the user
/// participates in.
///
/// Shows a profile header with a time-based greeting and an inline search,
/// then a [StreamBuilder]-driven list of conversation rows. Subscribes to
/// Pusher private channels so the list refreshes whenever a new direct or
/// group message arrives, and routes to [InboxScreen] or [GroupInboxScreen]
/// when a row is tapped.
class ChatScreen extends StatefulWidget {
  /// Creates the conversations screen.
  const ChatScreen({super.key});

  /// Creates the mutable state managing the Pusher connection and search.
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// State for [ChatScreen]; owns the realtime connection, the search state
/// and the cached conversation lists.
class _ChatScreenState extends State<ChatScreen> {
  /// Tracks whether the soft keyboard is currently visible.
  bool isKeyboardVisible = false;

  /// Controller for the (unused) inline chat input.
  final TextEditingController chatController = TextEditingController();

  /// Scroll controller for the conversation list.
  final ScrollController _scrollController = ScrollController();

  /// The Pusher websocket client, created in [connect].
  PusherChannelsClient? client;

  /// Subscription to the Pusher connection-established stream.
  StreamSubscription? connectionSubs;

  /// Merged subscription to the direct- and group-message channel events.
  StreamSubscription<ChannelReadEvent>? somePrivateChannelEventSubs;

  /// The current user's access token, used to authorize private channels.
  late final String userToken;

  /// Loads the chat list, reads the auth token and opens the Pusher
  /// connection.
  @override
  void initState() {
    super.initState();
    userToken = appData.read(kKeyAccessToken);
    // getAllMessageRx.getAllMessage();
    // getAllRoomRx.getRoomList();
    getAllChatRx.getAllChat();

    log("Token  is ================> $userToken");
    connect();
  }

  /// Cancels the Pusher subscriptions, disconnects the client and disposes
  /// the controllers.
  @override
  void dispose() {
    _scrollController.dispose();
    chatController.dispose();
    // _keyboardVisibilitySubscription.cancel();
    connectionSubs?.cancel();
    somePrivateChannelEventSubs?.cancel();
    client?.disconnect();
    super.dispose();
  }

  /// Opens the Pusher websocket connection and subscribes to the user's
  /// private direct-message and group-message channels.
  ///
  /// When either channel broadcasts a message-send event the chat list is
  /// reloaded via `getAllChatRx.getAllChat()` so previews stay current.
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

    final privateMessageChannel = client!.privateChannel(
      "private-chat-receiver.${appData.read(kKeyUserId)}",
      authorizationDelegate:
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
            authorizationEndpoint: Uri.parse(
              "https://reacti.io/api/broadcasting/auth",
            ),
            headers: {"Authorization": "Bearer $userToken"},
          ),
    );

    final groupMessageChannel = client!.privateChannel(
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
      log('==================== Connected to server =====================');
      privateMessageChannel.subscribeIfNotUnsubscribed();
      groupMessageChannel.subscribeIfNotUnsubscribed();
    });

    somePrivateChannelEventSubs = Rx.merge([
      privateMessageChannel.bind('App\\Events\\MessageSendEvent'),
      groupMessageChannel.bind('App\\Events\\GroupMessageSendEvent'),
    ]).listen((event) {
      log("===========Come Here==========");
      getAllChatRx.getAllChat();
      // final messageData = json.decode(event.data);
      // log("Received data: $messageData");
    });

    client!.connect();
  }

  /// Controller for the inline conversation search field.
  final _searchController = TextEditingController();

  /// Focus node used to focus the search field when search mode opens.
  final _searchFocusNode = FocusNode();

  /// Whether the header is currently in search mode.
  bool _isSearching = false;

  /// All conversations as returned by the API.
  List<Chat> allChats = [];

  /// The conversations currently displayed, narrowed by the search query.
  List<Chat> filterChats = [];

  /// Filters [filterChats] to the conversations whose name contains [query]
  /// (case-insensitive) and rebuilds the list.
  ///
  /// The filtering itself is delegated to the pure [filterChatsByName]
  /// helper so it can be unit-tested independently of the widget.
  void _filterChatList(String query) {
    setState(() {
      filterChats = filterChatsByName(allChats, query);
    });
  }

  /// Builds the screen: a profile/search header driven by the profile
  /// stream and a conversation list driven by the chat stream, with shimmer
  /// placeholders shown while either stream is loading.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100.h),
        child: StreamBuilder(
          stream: getProfileRx.getProfileStream,
          builder: (context, asyncSnapshot) {
            if (asyncSnapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 100.h,
                padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 8.h),
                alignment: Alignment.bottomCenter,
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Row(
                    spacing: 8.w,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Avatar shimmer
                      ClipOval(
                        child: Container(
                          height: 40.h,
                          width: 40.w,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),

                      // Title shimmer (Expanded text)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 18.h,
                              width: 180.w,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              height: 14.h,
                              width: 100.w,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Search Icon shimmer
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: Container(
                          height: 24.h,
                          width: 24.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (asyncSnapshot.hasData) {
              ProfileResponse response = asyncSnapshot.data;

              final data = response.data;
              return Container(
                alignment: Alignment.bottomCenter,
                // color: Colors.red,
                height: 100.h,
                padding: EdgeInsets.only(left: 16.w, bottom: 8.h, right: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 14.w,
                  children: [
                    InkWell(
                      onTap: () {},
                      child: ClipOval(
                        child: CustomNetworkImage(
                          height: 40.h,
                          width: 40.w,
                          urls: data?.avatar ?? "",
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          _isSearching
                              ? TextFormField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: (query) => _filterChatList(query),
                                decoration: InputDecoration(
                                  // prefixIcon: Icon(Icons.search),
                                  isDense: true,
                                  hintText: "Search User...",
                                  hintStyle:
                                      TextFontStyle
                                          .headline14w400C666666Poppins,
                                  border: OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppColors.allPrimaryColor,
                                      width: 0.5.w,
                                    ),
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  enabledBorder: OutlineInputBorder(),
                                ),
                                style:
                                    TextFontStyle.headline14w500CFFFFFFPoppins,
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                spacing: 2.h,
                                children: [
                                  Text(
                                    "Reacti",
                                    style: TextFontStyle
                                        .headline20w600CFFFFFFPoppins
                                        .copyWith(
                                          fontSize: 22.sp,
                                          color: AppColors.allPrimaryColor,
                                        ),
                                  ),
                                  Text(
                                    "${timeBasedGreeting(DateTime.now().hour)}, ${data?.firstName ?? ""}",
                                    style:
                                        TextFontStyle
                                            .headline14w500CFFFFFFPoppins,
                                  ),
                                ],
                              ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (_isSearching) {
                              _searchFocusNode.requestFocus();
                            } else {
                              _searchController.clear();
                              // _filterProducts("");
                            }
                          });
                        },
                        child:
                            _isSearching
                                ? Icon(
                                  Icons.close,
                                  color: AppColors.allPrimaryColor,
                                )
                                : SvgPicture.asset(
                                  Assets.icons.searchIcon,
                                  height: 18.h,
                                  width: 18.w,
                                ),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return SizedBox.shrink();
            }
          },
        ),
      ),
      body: StreamBuilder(
        stream: getAllChatRx.getChatStream,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              itemCount: 10, // number of shimmer items
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(bottom: 14.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.c18181B,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Shimmer.fromColors(
                    baseColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.5),
                    child: Row(
                      spacing: 10.w,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        ClipOval(
                          child: Container(
                            height: 40.h,
                            width: 40.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),

                        // Texts
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name shimmer
                              Container(
                                height: 18.h,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                              ),
                              SizedBox(height: 6.h),

                              // Last message shimmer
                              Container(
                                height: 14.h,
                                width: MediaQuery.of(context).size.width * 0.5,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Time shimmer
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              height: 14.h,
                              width: 40.w,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          } else if (asyncSnapshot.hasData) {
            ChatListResponse response = asyncSnapshot.data;
            allChats = response.data?.chats ?? [];
            if (!_isSearching) {
              filterChats = allChats;
            }
            return filterChats.isEmpty
                ? Center(
                  child: Text(
                    "No chats found",
                    style: TextFontStyle.headline14w500CFFFFFFPoppins,
                  ),
                )
                : ListView.builder(
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                  itemCount: filterChats.length,
                  itemBuilder: (context, index) {
                    final data = filterChats[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 14.h),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.r),
                        color: AppColors.c18181B,
                      ),
                      child: InkWell(
                        onTap: () {
                          if (data.type == "group") {
                            log("Room Id is =====> ${data.id}");
                            getGroupInboxRx
                                .getGroupInboxMessage(id: data.id ?? 0)
                                .waitingForSucess()
                                .then((success) {
                                  if (success) {
                                    NavigationService.navigateToWithArgs(
                                      Routes.groupInboxRoute,
                                      {
                                        'roomId': data.roomId,
                                        'name': data.name ?? "",
                                        'groupImage': data.avatar ?? "",
                                      },
                                    );
                                  }
                                });
                          } else {
                            getInboxMessageRx
                                .getInboxMessage(id: data.id!)
                                .waitingForSucess()
                                .then((success) {
                                  NavigationService.navigateToWithArgs(
                                    Routes.inboxRoute,
                                    {
                                      'id': data.id,
                                      'roomId': data.roomId,
                                      'name': data.name ?? "",
                                      'image': data.avatar ?? "",
                                    },
                                  );
                                });
                          }
                        },
                        child: Row(
                          spacing: 12.w,
                          children: [
                            ClipOval(
                              child: CustomNetworkImage(
                                height: 40.h,
                                width: 40.w,
                                urls:
                                    data.avatar ??
                                    "https://images.unsplash.com/photo-1678286742832-26543bb49959?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=688",
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 4.h,
                                children: [
                                  Text(
                                    data.name ?? "",
                                    style: TextFontStyle
                                        .headline16w500CFFFFFFPoppins
                                        .copyWith(fontSize: 18.sp),
                                  ),

                                  Text(
                                    data.lastMessage ?? "Start Conversation...",
                                    style:
                                        TextFontStyle
                                            .headline14w400CCCCCCCPoppins,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              // spacing: 4.h,
                              children: [
                                Text(
                                  data.lastMessageTime ?? "",
                                  style:
                                      TextFontStyle
                                          .headline14w400CCCCCCCPoppins,
                                ),
                                // Container(
                                //   padding: EdgeInsets.all(6.sp),
                                //   decoration: BoxDecoration(
                                //     shape: BoxShape.circle,
                                //     color: AppColors.allPrimaryColor,
                                //   ),
                                //   child: Text(
                                //     "2",
                                //     style: TextFontStyle
                                //         .headline14w400CCCCCCCPoppins
                                //         .copyWith(color: Color(0xFF333333)),
                                //   ),
                                // ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
          } else {
            return SizedBox.shrink();
          }
        },
      ),
    );
  }
}
