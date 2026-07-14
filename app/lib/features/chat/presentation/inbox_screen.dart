import 'dart:convert';
import 'dart:developer';

import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/data/inbox_seen_api.dart';
import 'package:reacti_app/features/chat/presentation/widget/sender_message_widget.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/media_prefetch.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../analytics/media_seal_analytics.dart';
import '../../../analytics/message_delivery_analytics.dart';
import '../../../constants/app_constants.dart';
import '../../../common_widget/load_error_retry.dart';
import '../../../helpers/di.dart';
import '../../../helpers/video_controller_cache.dart';
import '../../../networks/auth_token_store.dart';
import '../logic/message_reconciler.dart';
import '../model/inbox_response.dart';
import 'forward_picker_screen.dart';
import 'media_picker_mixin.dart';
import 'media_seal.dart';
import 'widget/chat_app_bar_title.dart';
import 'widget/message_thread_skeleton.dart';
import 'widget/chat_reply_banner.dart';
import 'widget/delete_message_sheet.dart';
import 'widget/inbox_blocked_notice.dart';
import 'widget/message_action_menu.dart';
import 'widget/message_details_sheet.dart';
import 'widget/message_edit_bar.dart';
import 'widget/receiver_message_widget.dart';
import 'widget/scroll_to_bottom_button.dart';
import 'widget/send_message_widget.dart';
import 'widget/unblock_button.dart';

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
class _InboxScreenState extends State<InboxScreen>
    with MediaPickerMixin<InboxScreen> {
  /// Controller backing the composer's text field.
  final _messageController = TextEditingController();

  /// Scroll controller for the (reversed) message list.
  final _scrollController = ScrollController();

  /// Owns the Pusher realtime connection for this screen.
  ///
  /// Built via [chatRealtimeServiceFactory] so tests can inject a fake; in
  /// production the factory returns a real [ChatRealtimeService].
  final ChatRealtimeService _realtime = chatRealtimeServiceFactory();

  /// The current user's access token, used to authorize the private channel.
  late final String userToken;

  /// Local, mutable copy of the conversation messages, newest-first.
  List<Chat> cList = [];

  /// Whether the local user keeps read receipts on (default on). Read from
  /// GetStorage so "seen" rendering can be gated synchronously; reciprocal —
  /// when off, we don't render the peer's seen state.
  bool get _readReceiptsEnabled {
    final v = appData.read(kKeyReadReceipts);
    return v is bool ? v : true;
  }

  /// Updates our own sent messages when the peer's read event arrives.
  ///
  /// Room-level part (always): mark our sent messages "read" so text shows the
  /// double-check. Per-message part: green ONLY the reaction the peer actually
  /// viewed ([viewedMessageId]) — a room-level read must NOT blanket-green every
  /// reaction (that caused reactions to turn green just from opening the chat).
  /// Never touches received messages or the mark-viewed/reaction-capture path.
  void _handleMessagesSeen(int? viewedMessageId) {
    final myId = appData.read(kKeyUserId);
    var changed = false;
    for (final m in cList) {
      if (m.senderId != myId) continue;
      if (m.status != 'read') {
        m.status = 'read';
        changed = true;
      }
      if (viewedMessageId != null && m.id == viewedMessageId && !m.isSeen) {
        m.isViewed = true;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  /// The last server response already folded into [cList]. Tracked so we
  /// re-sync only when a genuinely new response arrives (not on every
  /// rebuild), letting a re-entered screen adopt the fresh fetch instead of
  /// the stale value the shared stream replays first.
  InboxResponse? _lastAppliedResponse;

  /// Cursor lazy-load: how many messages a page holds (newest page on open,
  /// then older pages as the user scrolls up).
  static const int _pageSize = 20;

  /// id of the oldest message currently loaded — the cursor for the next older
  /// page. Null until the first page lands.
  int? _oldestLoadedId;

  /// Whether older messages remain (from the server's `has_more`). Stops the
  /// scroll-to-load once the start of the thread is reached.
  bool _hasMoreOlder = true;

  /// Guards against firing more than one older-page fetch at a time.
  bool _loadingOlder = false;

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

  /// The message currently being edited, or null when not in edit mode.
  /// While set, the composer is replaced by the [MessageEditBar].
  Chat? _editingMessage;

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

  /// Wires up the composer listener, reads the auth token, opens the Pusher
  /// connection, loads the conversation and attaches the scroll listener.
  @override
  void initState() {
    super.initState();

    _messageController.addListener(() {
      setState(() {});
    });
    userToken = AuthTokenStore.instance.token ?? '';
    connect();
    // Cursor lazy-load: fetch only the newest page on open; older pages load as
    // the user scrolls up (see _loadOlder). Falls back to the full thread on an
    // older backend that ignores `limit`.
    getInboxMessageRx.getInboxMessage(id: widget.id, limit: _pageSize);

    _scrollController.addListener(_scrollListener);
  }

  /// Toggles [_showScrollToBottom] and triggers older-page loading.
  void _scrollListener() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.offset > 200 && !_showScrollToBottom) {
      setState(() {
        _showScrollToBottom = true;
      });
    } else if (_scrollController.offset <= 200 && _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = false;
      });
    }

    // Reversed list: nearing maxScrollExtent means scrolling UP toward older
    // messages — fetch the next older page a little before the very top.
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300 &&
        _hasMoreOlder &&
        !_loadingOlder &&
        _oldestLoadedId != null) {
      _loadOlder();
    }
  }

  /// Fetches the next older page (messages before [_oldestLoadedId]) and
  /// appends it to the end of [cList] (the older end of the reversed list, so
  /// the visible newest area does not jump). Fire-and-forget; never throws.
  Future<void> _loadOlder() async {
    final cursor = _oldestLoadedId;
    if (cursor == null || _loadingOlder || !_hasMoreOlder) {
      return;
    }
    setState(() => _loadingOlder = true);

    final response = await getInboxMessageRx.fetchOlder(
      id: widget.id,
      before: cursor,
      limit: _pageSize,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _loadingOlder = false;
      final older = response?.data?.chat;
      if (older == null || older.isEmpty) {
        _hasMoreOlder = response?.data?.pagination?.hasMore ?? false;
        return;
      }
      // Older page is newest-first; append at the end (older) and dedup.
      cList = appendOlderInboxThread(cList, List<Chat>.from(older));
      _oldestLoadedId = cList.isNotEmpty ? cList.last.id : cursor;
      _hasMoreOlder = response?.data?.pagination?.hasMore ?? false;
    });

    // A small page may not fill the screen (nothing scrollable, so the
    // scroll-to-load trigger can't fire); keep pulling until the viewport fills.
    _maybeFillViewport();
  }

  /// If the thread doesn't fill the viewport yet (nothing scrollable) and older
  /// messages remain, load another page — so a small [_pageSize] still works on
  /// tall screens where the first page wouldn't otherwise be scrollable.
  void _maybeFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      if (_scrollController.position.maxScrollExtent <= 0 &&
          _hasMoreOlder &&
          !_loadingOlder &&
          _oldestLoadedId != null) {
        _loadOlder();
      }
    });
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
    _realtime.dispose();
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
    _realtime.connect(
      authToken: userToken,
      subscriptions: [
        ChatChannelSubscription(
          channelName: "private-chat-room.${widget.roomId}",
          eventName: 'App\\Events\\MessageSendEvent',
        ),
        ChatChannelSubscription(
          channelName: "private-chat-room.${widget.roomId}",
          eventName: 'MessageReadEvent',
        ),
      ],
      onEvent: (event) {
        // Read receipts: the peer opened the conversation or viewed media.
        // Its payload is {roomId, userId} with no 'chat' object, so handle it
        // before the MessageSendEvent parse below.
        if (event.name.contains('MessageRead')) {
          final data = json.decode(event.data);
          final viewedId = data['messageId'] ?? data['message_id'];
          _handleMessagesSeen(viewedId is int ? viewedId : null);
          return;
        }
        final messageData = json.decode(event.data);
        log("Received data =======> $messageData");

        log("Media Type =============> ${messageData['chat']['media_type']}");
        log(
          "Is Blur Media =============> ${messageData['chat']['is_blurred']}",
        );

        // Parse via the shared helper so the 1:1 and group realtime parses
        // can't silently drift — notably `message_type`, which gates the
        // media sender's on-play reaction "watched" signal.
        final newMessage = parseRealtimeInboxChat(messageData);

        // Observability: a realtime message landed for this recipient. Joined
        // with the server's message_persisted, this surfaces persisted-but-not-
        // delivered drops. Fire-and-forget — never blocks the merge below.
        trackMessageReceived(
          scope: 'private',
          messageType: messageTypeFromRealtime(
            rawType: messageData['chat']['message_type'],
            file: messageData['chat']['file'],
          ),
        );

        // Prefetch the media now (Pusher receipt) so tapping the blurred
        // placeholder later opens it from cache. Fire-and-forget.
        MediaPrefetch.onMessageReceived(
          file: messageData['chat']['file'],
          mediaType: messageData['chat']['media_type'],
        );

        setState(() {
          // Merge the incoming server message into the local list, reconciling
          // any outstanding optimistic entry. See `reconcileInboxMessage`.
          cList = reconcileInboxMessage(cList, newMessage);
        });

        // Live read receipt: we're sitting in the chat, so the peer's message
        // is read the moment it lands — mark it seen so their text double-check
        // upgrades live (not only when we re-open the chat). Fire-and-forget;
        // only for the peer's messages, never our own echoes.
        final myId = appData.read(kKeyUserId);
        if (newMessage.senderId != null && newMessage.senderId != myId) {
          InboxSeenApi.instance.markSeen(widget.id);
        }
      },
    );
  }

  /// Builds the conversation screen: an app bar with the peer and
  /// block/report menu, a stream-driven message list, the reply banner, the
  /// composer or block widgets, and a scroll-to-bottom button.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ChatAppBarTitle(name: widget.name, imageUrl: widget.image),
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
            return const MessageThreadSkeleton();
          } else if (asyncSnapshot.hasData) {
            InboxResponse response = asyncSnapshot.data;
            // Re-sync from each NEW server response (not just the first). On
            // re-entry the shared stream replays the stale previous response
            // before the fresh fetch lands; folding in every new response —
            // keeping in-flight optimistic entries — means the screen ends on
            // the fresh thread instead of locking onto stale data. A plain
            // rebuild (same response object) is skipped so realtime/optimistic
            // entries added via setState aren't clobbered.
            if (!identical(response, _lastAppliedResponse) &&
                response.data?.chat != null) {
              final wasEmpty = cList.isEmpty;
              _lastAppliedResponse = response;
              // Cursor mode returns messages newest-first; full-thread mode (and
              // ancient backends) return oldest-first and must be reversed.
              // has_more is sent in BOTH modes, so detect cursor by the absence
              // of the full-thread `per_page` key — see isCursorInboxResponse.
              final isCursor = isCursorInboxResponse(response.data!.pagination);
              final ordered =
                  isCursor
                      ? List<Chat>.from(response.data!.chat!)
                      : List<Chat>.from(response.data!.chat!.reversed);
              cList = mergeInboxThread(cList, ordered);
              _oldestLoadedId = cList.isNotEmpty ? cList.last.id : null;
              _hasMoreOlder = response.data!.pagination?.hasMore ?? false;
              // A small first page may not fill the screen — top up so
              // scroll-to-load still works.
              _maybeFillViewport();
              if (wasEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _precacheMedia();
                });
              }
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
                        // One extra trailing slot (top of the reversed list) for
                        // the "loading older messages" spinner.
                        itemCount: cList.length + (_loadingOlder ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= cList.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: Center(
                                child: SizedBox(
                                  height: 20.h,
                                  width: 20.h,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final data = cList[index];
                          final isMine =
                              data.sender?.id == appData.read(kKeyUserId);
                          if (!isMine) {
                            // Seal-integrity signal for received media (1:1);
                            // deduped by message id inside the tracker.
                            trackMediaReceivedSealState(
                              messageId: data.id,
                              mediaType: data.mediaType,
                              messageType: data.messageType,
                              sealed: isMediaSealed(data.isBlurred),
                              scope: 'private',
                              file: data.file,
                            );
                          }
                          return isMine
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
                                // Without this the bubble can't tell a reaction
                                // from plain media, so 1:1 reactions rendered as
                                // media (no "Reaction" label, no watched dot).
                                messageType: data.messageType,
                                isBlocked: response.data?.isBlocked,
                                messageId: data.id!,
                                receiverId: widget.id,
                                isLocal: data.isLocal == true,
                                localPath: data.localPath,
                                uploadProgress: data.uploadProgress,
                                isHighlighted: _highlightedMessageId == data.id,
                                // Text "seen" is the peer's read status; a
                                // reaction's "watched" is its is_viewed flag.
                                // (Media shows no tick.)
                                isSeen:
                                    data.messageType == 'reaction'
                                        ? data.isSeen
                                        : data.status == 'read',
                                readReceiptsEnabled: _readReceiptsEnabled,
                                isEdited: data.isEdited == true,
                                isForwarded: data.isForwarded == true,
                                onLongPress: (position) {
                                  _showMessageMenu(
                                    context,
                                    position,
                                    data,
                                    index,
                                    isMine: true,
                                  );
                                },
                                onReply: () => _replyToMessage(data),
                                replyTo: data.replyTo,
                                onTapReply: _jumpToMessage,
                              )
                              : ReceiverMessageWidget(
                                key: _messageKeys.putIfAbsent(
                                  data.id ?? 0,
                                  () => GlobalKey(),
                                ),
                                message: data.text ?? "",
                                // The sender is the friend on a received bubble;
                                // receiver is the current user (the owner bug).
                                avatar: data.sender?.avatar ?? "",
                                firstName: data.sender?.firstName,
                                lastName: data.sender?.lastName,
                                time: data.humanizeDate ?? "",
                                file: data.file,
                                fileType: data.mediaType,
                                // Needed so a received reaction is recognised as
                                // one — it gates marking the reaction "watched"
                                // (which greens the sender's dot).
                                messageType: data.messageType,
                                // Seal media for the receiver, tolerating both the
                                // REST bool and realtime int forms of is_blurred.
                                isBlurred: isMediaSealed(data.isBlurred),
                                isHighlighted: _highlightedMessageId == data.id,
                                messageId: data.id,
                                userId: widget.id,
                                // No optimistic insert here: in 1:1 the reactor is
                                // on the room channel, so the realtime echo gets
                                // reconciled in and stripped the reaction styling
                                // (it rendered as plain media until a re-enter).
                                // Instead, refetch on success so the correct
                                // server copy (with its "Reaction" header + dot)
                                // shows automatically. mergeInboxThread dedupes by
                                // id, so the echo + refetch never double it.
                                onReactionSuccess: (tempId, success, serverId) {
                                  if (success) {
                                    // Adopt the real server id into the
                                    // optimistic reaction immediately so the
                                    // live "watched" event (which carries the
                                    // real id) can match it — otherwise a fast
                                    // media-sender watch races the re-fetch
                                    // below and the dot only greens on a later
                                    // watch.
                                    if (serverId != null) {
                                      final index = cList.indexWhere(
                                        (item) => item.id == tempId,
                                      );
                                      if (index != -1) {
                                        setState(() {
                                          cList[index] = cList[index].copyWith(
                                            id: serverId,
                                            isLocal: false,
                                          );
                                        });
                                      }
                                    }
                                    getInboxMessageRx.getInboxMessage(
                                      id: widget.id,
                                    );
                                  }
                                },
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
                                onReply: () => _replyToMessage(data),
                                isEdited: data.isEdited == true,
                                isForwarded: data.isForwarded == true,
                                onLongPress: (position) {
                                  _showMessageMenu(
                                    context,
                                    position,
                                    data,
                                    index,
                                    isMine: false,
                                  );
                                },
                                replyTo: data.replyTo,
                                onTapReply: _jumpToMessage,
                              );
                        },
                      ),
                    ),
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
                    if (response.data?.isBlocked == false &&
                        _editingMessage != null)
                      MessageEditBar(
                        initialText: _editingMessage!.text ?? "",
                        onCancel: _cancelEditing,
                        onSubmit: _submitEdit,
                      ),
                    if (response.data?.isBlocked == false &&
                        _editingMessage == null)
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
                            // The send call reported failure — but the backend
                            // may have persisted the message anyway (it saves
                            // the row before its best-effort broadcast/push and
                            // can still return an error afterwards). Removing the
                            // optimistic bubble alone made a saved message
                            // "vanish" until the user left and re-opened the
                            // chat. So drop the optimistic entry AND re-sync from
                            // the server: a saved message reappears immediately,
                            // a genuinely failed one stays gone.
                            setState(() {
                              cList.removeWhere((chat) => chat.id == tempId);
                            });
                            getInboxMessageRx.getInboxMessage(id: widget.id);
                          }
                        },
                        type: 'image',
                        onTapMedia: () {
                          showMediaPicker(context);
                        },
                        isGroup: false,
                        // image: ValueNotifier<List<AssetEntity>>([]),
                      ),

                    if (response.data?.isBlocked == true &&
                        response.data?.blockByMe == true)
                      UnblockButton(onTap: _unblockUser),
                    if (response.data?.isBlocked == true &&
                        response.data?.blockByMe != true)
                      const InboxBlockedNotice(),
                  ],
                ),
              ),
            );
          } else if (asyncSnapshot.hasError) {
            // A failed load previously showed a blank screen; surface a
            // message and a retry that re-fetches the conversation.
            return LoadErrorRetry(
              message: "Couldn't load this conversation.",
              onRetry: () => getInboxMessageRx.getInboxMessage(id: widget.id),
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
      floatingActionButton:
          _showScrollToBottom
              ? ScrollToBottomButton(onPressed: _scrollToBottom)
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Unblocks the peer and, on success, surfaces a toast and reloads the
  /// conversation. Backs the [UnblockButton] shown when the current user
  /// has blocked the peer.
  void _unblockUser() {
    blockUserRx.blockUser(id: widget.id).waitingForSuccess().then((success) {
      if (success) {
        ToastUtil.showSuccessMessage("User unblocked successfully");
        getInboxMessageRx.getInboxMessage(id: widget.id);
      }
    });
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

  /// Opens the WhatsApp-style action menu for [data] at the press [position].
  ///
  /// The offered actions depend on ownership and kind: reply and details are
  /// always available; text messages can be copied; the user's own messages
  /// can be deleted. Forward and edit arrive in later phases.
  void _showMessageMenu(
    BuildContext context,
    Offset position,
    Chat data,
    int index, {
    required bool isMine,
  }) {
    final hasText = (data.text ?? "").trim().isNotEmpty;
    final actions = <MessageAction>[
      MessageAction(
        icon: Icons.reply_rounded,
        label: "Reply",
        onTap: () => _replyToMessage(data),
      ),
      MessageAction(
        icon: Icons.forward_rounded,
        label: "Forward",
        onTap: () => _forwardMessage(data),
      ),
      if (hasText)
        MessageAction(
          icon: Icons.copy_rounded,
          label: "Copy",
          onTap: () => _copyMessage(data),
        ),
      // Edit is offered for the user's own text messages (never reactions);
      // the server enforces the 10-minute window and rejects a late edit.
      if (isMine && hasText && data.messageType != 'reaction')
        MessageAction(
          icon: Icons.edit_outlined,
          label: "Edit",
          onTap: () => _startEditing(data),
        ),
      MessageAction(
        icon: Icons.info_outline_rounded,
        label: "Details",
        onTap: () => _showMessageDetails(data, isMine: isMine),
      ),
      if (isMine)
        MessageAction(
          icon: Icons.delete_outline_rounded,
          label: "Delete",
          isDestructive: true,
          onTap: () => _deleteMessageDialog(context, data, index),
        ),
    ];
    showMessageActionMenu(context, tapPosition: position, actions: actions);
  }

  /// Opens the recipient picker to forward [data] to other conversations.
  void _forwardMessage(Chat data) {
    if (data.id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ForwardPickerScreen(
              sourceMessageId: data.id!,
              sourceType: 'single',
            ),
      ),
    );
  }

  /// Stages a reply to [data] in the composer. Shared by swipe-to-reply and
  /// the action menu so both routes build the quoted preview identically.
  void _replyToMessage(Chat data) {
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
  }

  /// Copies [data]'s text to the clipboard and confirms with a toast.
  void _copyMessage(Chat data) {
    Clipboard.setData(ClipboardData(text: data.text ?? ""));
    ToastUtil.showSuccessMessage("Copied");
  }

  /// Enters edit mode for [data], replacing the composer with the edit bar.
  /// Any in-progress reply is cleared so the two modes never overlap.
  void _startEditing(Chat data) {
    setState(() {
      _editingMessage = data;
      _replyMessage = null;
      _replyImage = null;
      _replyMediaType = null;
      _replyToId = null;
      _replyToData = null;
    });
  }

  /// Leaves edit mode without saving.
  void _cancelEditing() {
    setState(() => _editingMessage = null);
  }

  /// Persists the edited [text] for [_editingMessage] via the edit API and,
  /// on success, updates the local message (text + "edited" flag) and leaves
  /// edit mode. On failure the edit bar stays open (the Rx toasts the reason,
  /// e.g. the message is past its 10-minute edit window).
  void _submitEdit(String text) {
    final data = _editingMessage;
    if (data?.id == null) return;

    editMessageRx.editMessage(messageId: data!.id!, text: text).then((success) {
      if (!success || !mounted) return;
      setState(() {
        final index = cList.indexWhere((chat) => chat.id == data.id);
        if (index != -1) {
          cList[index] = cList[index].copyWith(text: text, isEdited: true);
        }
        _editingMessage = null;
      });
    });
  }

  /// Shows the message-info sheet: the send time, plus a delivery-status label
  /// for the user's own messages (received messages have no outgoing status).
  void _showMessageDetails(Chat data, {required bool isMine}) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => MessageDetailsSheet(
            sentAt: (data.humanizeDate ?? "").toString(),
            statusLabel: isMine ? _statusLabel(data) : null,
          ),
    );
  }

  /// Maps a message's delivery state to a human label for the details sheet.
  /// A reaction's "seen" is its watched flag; other messages use [Chat.status].
  String _statusLabel(Chat data) {
    if (data.messageType == 'reaction') {
      return data.isSeen ? "Seen" : "Sent";
    }
    switch (data.status) {
      case 'read':
        return "Seen";
      case 'delivered':
        return "Delivered";
      default:
        return "Sent";
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
          (_) => DeleteMessageSheet(
            onConfirm: () {
              log("Delete Conversation");

              deleteMessageRx
                  .deleteMessage(messageId: data.id!)
                  .waitingForSuccess()
                  .then((success) {
                    cList.removeAt(index);
                    getInboxMessageRx.getInboxMessage(id: widget.id);
                  });
              Navigator.pop(context);
            },
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
      icon: Icon(Icons.more_vert, color: context.reacti.iconPrimary),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      onSelected: (value) {
        if (value == 'block') {
          blockUserRx.blockUser(id: widget.id).waitingForSuccess().then((
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
