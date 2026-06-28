import 'dart:developer';

import 'package:reacti_app/common_widget/custom_network_image.dart';
import 'package:reacti_app/common_widget/load_error_retry.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/model/chat_list_response.dart';
import 'package:reacti_app/features/profile/model/profile_response.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constants/app_constants.dart';
import '../../../helpers/di.dart';
import '../../../networks/auth_token_store.dart';
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

  /// Owns the Pusher realtime connection for this screen.
  final ChatRealtimeService _realtime = ChatRealtimeService();

  /// The current user's access token, used to authorize private channels.
  late final String userToken;

  /// Loads the chat list, reads the auth token and opens the Pusher
  /// connection.
  @override
  void initState() {
    super.initState();
    userToken = AuthTokenStore.instance.token ?? '';
    // getAllMessageRx.getAllMessage();
    // getAllRoomRx.getRoomList();
    getAllChatRx.getAllChat();

    connect();
  }

  /// Cancels the Pusher subscriptions, disconnects the client and disposes
  /// the controllers.
  @override
  void dispose() {
    _scrollController.dispose();
    chatController.dispose();
    // _keyboardVisibilitySubscription.cancel();
    _realtime.dispose();
    super.dispose();
  }

  /// Opens the Pusher websocket connection and subscribes to the user's
  /// private direct-message and group-message channels.
  ///
  /// When either channel broadcasts a message-send event the chat list is
  /// reloaded via `getAllChatRx.getAllChat()` so previews stay current.
  void connect() async {
    _realtime.connect(
      authToken: userToken,
      subscriptions: [
        ChatChannelSubscription(
          channelName: "private-chat-receiver.${appData.read(kKeyUserId)}",
          eventName: 'App\\Events\\MessageSendEvent',
        ),
        ChatChannelSubscription(
          channelName: "private-group-message.${appData.read(kKeyUserId)}",
          eventName: 'App\\Events\\GroupMessageSendEvent',
        ),
      ],
      onEvent: (event) {
        log("===========Come Here==========");
        getAllChatRx.getAllChat();
        // final messageData = json.decode(event.data);
        // log("Received data: $messageData");
      },
    );
  }

  /// Controller for the inline conversation search field.
  final _searchController = TextEditingController();

  /// Focus node used to focus the search field when search mode opens.
  final _searchFocusNode = FocusNode();

  /// Whether the header is currently in search mode.
  bool _isSearching = false;

  /// All conversations as returned by the API.
  List<Chat> allChats = [];

  /// The active top-of-list filter (All / 1:1 / Groups / Unseen).
  ChatFilter _activeFilter = ChatFilter.all;

  /// Rebuilds the list when the search query changes; the displayed list is
  /// recomputed in [build] from the search text and [_activeFilter] via the
  /// pure [filterChatsByName] / [applyChatFilter] helpers.
  void _filterChatList(String query) {
    setState(() {});
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
                    // New-group action, re-homed here from the removed
                    // bottom-bar center button. Hidden while searching to keep
                    // the field roomy.
                    if (!_isSearching)
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: GestureDetector(
                          onTap:
                              () => NavigationService.navigateTo(
                                Routes.createGroupRoute,
                              ),
                          child: Icon(
                            Icons.add,
                            size: 24.sp,
                            color: AppColors.allPrimaryColor,
                            semanticLabel: 'New group',
                          ),
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
      body: Column(
        children: [
          SizedBox(height: 8.h),
          _buildFilterChips(),
          SizedBox(height: 4.h),
          Expanded(child: _buildChatList()),
        ],
      ),
    );
  }

  /// Builds the conversation list driven by the chat stream, with shimmer
  /// placeholders while loading and an error/empty state otherwise.
  Widget _buildChatList() {
    return StreamBuilder(
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
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
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
          final searched = filterChatsByName(
            allChats,
            _isSearching ? _searchController.text : '',
          );
          final displayed = applyChatFilter(searched, _activeFilter);
          return displayed.isEmpty
              ? Center(
                child: Text(
                  "No chats found",
                  style: TextFontStyle.headline14w500CFFFFFFPoppins,
                ),
              )
              : ListView.builder(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                itemCount: displayed.length,
                itemBuilder: (context, index) {
                  final data = displayed[index];
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
                              .waitingForSuccess()
                              .then((success) {
                                if (success) {
                                  // Refresh on return so the unseen counts /
                                  // Unseen filter update once the thread is
                                  // opened (the backend marks it read).
                                  NavigationService.navigateToWithArgs(
                                    Routes.groupInboxRoute,
                                    {
                                      'roomId': data.roomId,
                                      'name': data.name ?? "",
                                      'groupImage': data.avatar ?? "",
                                    },
                                  ).then((_) => getAllChatRx.getAllChat());
                                }
                              });
                        } else {
                          getInboxMessageRx
                              .getInboxMessage(id: data.id!)
                              .waitingForSuccess()
                              .then((success) {
                                // Refresh on return so unseen counts update.
                                NavigationService.navigateToWithArgs(
                                  Routes.inboxRoute,
                                  {
                                    'id': data.id,
                                    'roomId': data.roomId,
                                    'name': data.name ?? "",
                                    'image': data.avatar ?? "",
                                  },
                                ).then((_) => getAllChatRx.getAllChat());
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
                                    TextFontStyle.headline14w400CCCCCCCPoppins,
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
        } else if (asyncSnapshot.hasError) {
          // A failed load previously rendered a blank screen; show a
          // message and a retry that re-runs the chat-list fetch.
          return LoadErrorRetry(
            message: "Couldn't load your chats.",
            onRetry: () => getAllChatRx.getAllChat(),
          );
        } else {
          return SizedBox.shrink();
        }
      },
    );
  }

  /// Builds the horizontal filter-chip row (All / 1:1 / Groups / Unseen).
  ///
  /// Scrolls horizontally so it never overflows, and follows the ambient
  /// text direction (RTL for Hebrew). The Unseen chip carries a count badge
  /// summed across all conversations.
  Widget _buildFilterChips() {
    final unseen = totalUnread(allChats);
    return SizedBox(
      height: 38.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _filterChip(label: "All", filter: ChatFilter.all),
          _filterChip(label: "1:1", filter: ChatFilter.direct),
          _filterChip(label: "Groups", filter: ChatFilter.groups),
          _filterChip(
            label: "Unseen",
            filter: ChatFilter.unseen,
            badge: unseen,
          ),
        ],
      ),
    );
  }

  /// Builds one selectable filter chip, optionally with a count [badge].
  Widget _filterChip({
    required String label,
    required ChatFilter filter,
    int badge = 0,
  }) {
    final bool selected = _activeFilter == filter;
    final labelStyle = TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
      color: selected ? AppColors.c333333 : AppColors.cFFFFFF,
    );

    return Padding(
      padding: EdgeInsetsDirectional.only(end: 8.w),
      child: ChoiceChip(
        showCheckmark: false,
        selected: selected,
        onSelected: (_) => setState(() => _activeFilter = filter),
        backgroundColor: AppColors.c252529,
        selectedColor: AppColors.allPrimaryColor,
        side: BorderSide.none,
        label:
            badge > 0
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: labelStyle),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected
                                ? AppColors.c333333
                                : AppColors.allPrimaryColor,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        '$badge',
                        style: TextFontStyle.headline12w400CDDDDDDPoppins
                            .copyWith(
                              color:
                                  selected
                                      ? AppColors.allPrimaryColor
                                      : AppColors.c333333,
                            ),
                      ),
                    ),
                  ],
                )
                : Text(label, style: labelStyle),
      ),
    );
  }
}
