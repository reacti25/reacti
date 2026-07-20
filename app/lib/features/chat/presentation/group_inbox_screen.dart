import 'dart:convert';
import 'dart:developer';

import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/data/group_mark_read_api.dart';
import 'package:reacti_app/features/chat/logic/edit_window.dart';
import 'package:reacti_app/features/chat/logic/message_reconciler.dart';
import 'package:reacti_app/features/chat/model/group_inbox_response.dart';
import 'package:reacti_app/features/chat/presentation/widget/receiver_message_widget.dart';
import 'package:reacti_app/features/chat/presentation/widget/sender_message_widget.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/feedback_service.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/media_prefetch.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../analytics/media_seal_analytics.dart';
import '../../../analytics/message_delivery_analytics.dart';
import '../../../constants/app_constants.dart';
import '../../../common_widget/load_error_retry.dart';
import '../../../helpers/di.dart';
import '../../../networks/auth_token_store.dart';
import '../../../networks/api_access.dart';
import 'forward_picker_screen.dart';
import 'media_picker_mixin.dart';
import 'media_seal.dart';
import 'widget/chat_app_bar_title.dart';
import 'widget/chat_reply_banner.dart';
import 'widget/delete_choice_sheet.dart';
import 'widget/message_action_menu.dart';
import 'widget/message_details_sheet.dart';
import 'widget/message_edit_bar.dart';
import 'widget/message_thread_skeleton.dart';
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
class _GroupInboxScreenState extends State<GroupInboxScreen>
    with MediaPickerMixin<GroupInboxScreen> {
  /// Controller backing the composer's text field.
  final _messageController = TextEditingController();

  /// Scroll controller for the (reversed) message list.
  final ScrollController _scrollController = ScrollController();

  /// Owns the Pusher realtime connection for this screen.
  final ChatRealtimeService _realtime = chatRealtimeServiceFactory();

  /// The current user's access token, used to authorize the private channel.
  late final String userToken;

  /// Local, mutable copy of the group messages, newest-first.
  List<Message> cList = [];

  /// Whether the local user keeps read receipts on (default on); gates "seen"
  /// rendering. Reciprocal — off means we don't render others' seen state.
  bool get _readReceiptsEnabled {
    final v = appData.read(kKeyReadReceipts);
    return v is bool ? v : true;
  }

  // MediaPickerMixin hooks: group sends target the room id and are a group.
  @override
  int get mediaConversationId => widget.roomId;

  @override
  bool get isGroupConversation => true;

  @override
  int insertOptimisticMedia(XFile file, String mediaType, String caption) {
    final tempId = DateTime.now().microsecondsSinceEpoch;
    final localMessage = Message(
      id: tempId,
      senderId: appData.read(kKeyUserId),
      groupId: widget.roomId,
      text: caption,
      file: file.path,
      localPath: file.path,
      mediaType: mediaType,
      isLocal: true,
      createdAt: "Just now",
      sender: Sender(id: appData.read(kKeyUserId), firstName: "Me"),
    );
    setState(() => cList.insert(0, localMessage));
    return tempId;
  }

  @override
  void reconcileOptimisticMedia(int tempId, bool success) {
    if (success) {
      setState(() {
        final i = cList.indexWhere((c) => c.id == tempId);
        if (i != -1) cList[i] = cList[i].copyWith(isLocal: false);
      });
    } else {
      setState(() => cList.removeWhere((c) => c.id == tempId));
      getGroupInboxRx.getGroupInboxMessage(id: widget.roomId, limit: _pageSize);
    }
  }

  /// The last server response already folded into [cList]. Tracked so we
  /// re-sync only when a genuinely new response arrives (not on every
  /// rebuild), which is what lets a re-entered screen adopt the fresh fetch
  /// instead of the stale value the shared stream replays first.
  GroupInboxResponse? _lastAppliedResponse;

  /// Cursor lazy-load: how many messages a page holds (newest page on open,
  /// then older pages as the user scrolls up).
  static const int _pageSize = 6;

  /// id of the oldest message currently loaded — the cursor for the next older
  /// page. Null until the first page lands.
  int? _oldestLoadedId;

  /// Whether older messages remain (from the server's `has_more`). Stops the
  /// scroll-to-load once the start of the thread is reached.
  bool _hasMoreOlder = true;

  /// Guards against firing more than one older-page fetch at a time.
  bool _loadingOlder = false;

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

  /// The group message currently being edited, or null when not in edit mode.
  /// While set, the composer is replaced by the [MessageEditBar].
  Message? _editingMessage;

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

  /// Opens the WhatsApp-style action menu for [data] at the press [position].
  ///
  /// Group messages offer reply, copy (text only), details, and delete. Group
  /// delete is "for me" only — the sole group-delete-for-everyone endpoint is
  /// admin-only bulk, so a per-message sender-scoped one is a later follow-up.
  void _showMessageMenu(
    BuildContext context,
    Offset position,
    Message data, {
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
      // Edit is offered for the user's own text messages (never reactions),
      // and only while still inside the 10-minute window — evaluated as the
      // menu opens, so it disappears once the window has passed rather than
      // showing then failing. The server still enforces the window.
      if (isMine &&
          hasText &&
          data.messageType != 'reaction' &&
          canEditMessageAt(data.sentAtUtc, DateTime.now().toUtc()))
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
      // Only "delete for me" is offered in groups — the sole group-delete
      // endpoint is admin-only bulk, so per-message "for everyone" isn't wired.
      MessageAction(
        icon: Icons.delete_outline_rounded,
        label: "Delete",
        isDestructive: true,
        onTap: () => _deleteForMeDialog(data),
      ),
    ];
    showMessageActionMenu(context, tapPosition: position, actions: actions);
  }

  /// Opens the recipient picker to forward [data] to other conversations.
  void _forwardMessage(Message data) {
    if (data.id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ForwardPickerScreen(
              sourceMessageId: data.id!,
              sourceType: 'group',
            ),
      ),
    );
  }

  /// Shows the delete-choice sheet for a group message — "Delete for me" only.
  /// On success the message is hidden locally (and server-side, synced).
  void _deleteForMeDialog(Message data) {
    if (data.id == null) return;
    showModalBottomSheet(
      context: context,
      builder:
          (_) => DeleteChoiceSheet(
            onDeleteForMe: () {
              Navigator.pop(context);
              deleteForMeRx.deleteGroupForMe(messageId: data.id!).then((
                success,
              ) {
                if (success && mounted) {
                  setState(() => cList.removeWhere((m) => m.id == data.id));
                }
              });
            },
          ),
    );
  }

  /// Stages a reply to [data] in the composer. Shared by swipe-to-reply and
  /// the action menu so both routes build the quoted preview identically.
  void _replyToMessage(Message data) {
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
  }

  /// Copies [data]'s text to the clipboard and confirms with a toast.
  void _copyMessage(Message data) {
    Clipboard.setData(ClipboardData(text: data.text ?? ""));
    ToastUtil.showSuccessMessage("Copied");
  }

  /// Enters edit mode for [data], replacing the composer with the edit bar.
  /// Any in-progress reply is cleared so the two modes never overlap.
  void _startEditing(Message data) {
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

  /// Persists the edited [text] for [_editingMessage] via the group edit API
  /// and, on success, updates the local message (text + "edited" flag) and
  /// leaves edit mode. On failure the edit bar stays open (the Rx toasts the
  /// reason, e.g. past the 10-minute edit window).
  void _submitEdit(String text) {
    final data = _editingMessage;
    if (data?.id == null) return;

    editGroupMessageRx
        .editGroupMessage(
          groupId: widget.roomId,
          messageId: data!.id!,
          text: text,
        )
        .then((success) {
          if (!success || !mounted) return;
          setState(() {
            final index = cList.indexWhere((msg) => msg.id == data.id);
            if (index != -1) {
              cList[index] = cList[index].copyWith(text: text, isEdited: true);
            }
            _editingMessage = null;
          });
        });
  }

  /// Shows the message-info sheet: the send time, plus a "seen" label for the
  /// user's own messages (received messages have no outgoing status).
  void _showMessageDetails(Message data, {required bool isMine}) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => MessageDetailsSheet(
            sentAt: (data.createdAt ?? "").toString(),
            statusLabel: isMine ? _statusLabel(data) : null,
          ),
    );
  }

  /// Maps a group message's seen state to a human label for the details sheet.
  /// A reaction is "seen" once any recipient watched it; other messages once
  /// every other member has read them.
  String _statusLabel(Message data) {
    final seen =
        data.messageType == 'reaction' ? data.seenByOthers : data.seenByAll;
    return seen ? "Seen" : "Sent";
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

    final response = await getGroupInboxRx.fetchOlder(
      id: widget.roomId,
      before: cursor,
      limit: _pageSize,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _loadingOlder = false;
      final older = response?.data?.messages;
      if (older == null || older.isEmpty) {
        _hasMoreOlder = response?.data?.pagination?.hasMore ?? false;
        return;
      }
      // Older page is newest-first; append at the end (older) and dedup.
      cList = appendOlderGroupThread(cList, List<Message>.from(older));
      _oldestLoadedId = cList.isNotEmpty ? cList.last.id : cursor;
      _hasMoreOlder = response?.data?.pagination?.hasMore ?? false;
    });

    // With a small page size the loaded messages may not fill the screen, so
    // there is nothing to scroll and the scroll-to-load trigger can't fire.
    // Keep pulling older pages until the viewport is filled (or no more).
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

  /// Wires up the composer listener, reads the auth token, opens the Pusher
  /// connection, loads the group conversation and attaches the scroll
  /// listener.
  @override
  void initState() {
    super.initState();

    _messageController.addListener(() {
      setState(() {});
    });
    userToken = AuthTokenStore.instance.token ?? '';
    connect();
    // Cursor lazy-load: fetch only the newest page on open; older pages load as
    // the user scrolls up (see _loadOlder). Falls back to the full thread on
    // older backends that ignore `limit`.
    getGroupInboxRx.getGroupInboxMessage(id: widget.roomId, limit: _pageSize);

    // Opening the group marks its messages read so the chat-list "Unseen"
    // count clears on return. Fire-and-forget — never blocks opening the group.
    GroupMarkReadApi.instance.markRead(widget.roomId);

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
        ChatChannelSubscription(
          channelName: "private-group-message.${appData.read(kKeyUserId)}",
          eventName: 'GroupMessageViewedEvent',
        ),
        ChatChannelSubscription(
          channelName: "private-group-message.${appData.read(kKeyUserId)}",
          eventName: 'GroupMessageReadEvent',
        ),
      ],
      onEvent: (event) {
        // The original media sender watched one of our reactions — flip its
        // "watched" dot green live. Payload carries only the viewed message id.
        if (event.name.contains('GroupMessageViewed')) {
          final data = json.decode(event.data);
          final viewedId = data['messageId'] ?? data['message_id'];
          if (viewedId != null) {
            final index = cList.indexWhere((m) => m.id == viewedId);
            if (index != -1 && !cList[index].seenByOthers && mounted) {
              setState(() {
                cList[index] = cList[index].copyWith(seenByOthers: true);
              });
            }
          }
          return;
        }
        // All other members have now read one of our messages — flip its text
        // double-check live. Payload carries the read message id.
        if (event.name.contains('GroupMessageRead')) {
          final data = json.decode(event.data);
          final readId = data['messageId'] ?? data['message_id'];
          if (readId != null) {
            final index = cList.indexWhere((m) => m.id == readId);
            if (index != -1 && !cList[index].seenByAll && mounted) {
              setState(() {
                cList[index] = cList[index].copyWith(seenByAll: true);
              });
            }
          }
          return;
        }
        final messageData = json.decode(event.data);
        log("Received data ============>  $messageData");

        final newMessage = Message(
          id: messageData['message']['id'],
          senderId: messageData['message']['sender_id'],
          groupId: messageData['message']['group_id'],
          text: messageData['message']['text'],
          createdAt: messageData['message']['created_at'],
          sentAtUtc:
              messageData['message']['created_at_utc'] == null
                  ? null
                  : DateTime.tryParse(
                    messageData['message']['created_at_utc'],
                  )?.toUtc(),
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
                    mediaType: messageData['message']['reply_to']['media_type'],
                    isBlurred: messageData['message']['reply_to']['is_blurred'],
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

        // Observability: a realtime group message landed for this recipient.
        // Joined with the server's message_persisted, this surfaces
        // persisted-but-not-delivered drops. Fire-and-forget.
        trackMessageReceived(
          scope: 'group',
          messageType: messageTypeFromRealtime(
            rawType: messageData['message']['message_type'],
            file: messageData['message']['file'],
          ),
        );

        // Prefetch the media now (Pusher receipt) so tapping the blurred
        // placeholder later opens it from cache. Fire-and-forget.
        MediaPrefetch.onMessageReceived(
          file: messageData['message']['file'],
          mediaType: messageData['message']['media_type'],
        );

        setState(() {
          // Merge the incoming server message into the local list,
          // reconciling any optimistic entry. See `reconcileGroupMessage`.
          cList = reconcileGroupMessage(cList, newMessage);
        });

        // Live read receipt: we're in the group, so a member's message is read
        // the moment it lands — mark it read so the sender's text double-check
        // upgrades live (not only when we re-open the group). Fire-and-forget;
        // only for others' messages, never our own echoes.
        final myId = appData.read(kKeyUserId);
        if (newMessage.senderId != null && newMessage.senderId != myId) {
          GroupMarkReadApi.instance.markRead(widget.roomId);
          // Subtle tick for a genuinely-new inbound message (not our own echo).
          FeedbackService.messageReceived();
        }
      },
    );
  }

  /// Builds the group conversation screen: an app bar that opens group
  /// details, a stream-driven message list, the reply banner, the composer
  /// and a scroll-to-bottom button.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            groupDetailsRx
                .getGroupDetails(id: widget.roomId)
                .waitingForSuccess()
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
            isGroup: true,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: getGroupInboxRx.getGroupInboxStream,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return const MessageThreadSkeleton();
          } else if (asyncSnapshot.hasData) {
            GroupInboxResponse response = asyncSnapshot.data;
            // Re-sync from each NEW server response (not just the first one).
            // On re-entry the shared stream replays the stale previous
            // response before the fresh fetch lands; folding in every new
            // response — keeping in-flight optimistic entries — means the
            // screen ends on the fresh thread instead of locking onto stale
            // data and dropping messages sent in between. Same response
            // object (a plain rebuild) is skipped so realtime/optimistic
            // entries added via setState aren't clobbered.
            if (!identical(response, _lastAppliedResponse) &&
                response.data?.messages != null) {
              _lastAppliedResponse = response;
              // Cursor mode returns messages newest-first; full-thread mode
              // (and ancient backends) return oldest-first and must be
              // reversed. The backend sends has_more in BOTH modes, so detect
              // cursor by the absence of the full-thread `per_page` key — see
              // isCursorGroupResponse. Using has_more here mis-classified the
              // full-thread response as cursor and showed it un-reversed,
              // pushing a just-sent message off the top (it "vanished" until
              // you left and re-entered).
              final isCursor = isCursorGroupResponse(response.data!.pagination);
              final ordered =
                  isCursor
                      ? List<Message>.from(response.data!.messages!)
                      : List<Message>.from(response.data!.messages!.reversed);
              cList = mergeGroupThread(cList, ordered);
              _oldestLoadedId = cList.isNotEmpty ? cList.last.id : null;
              _hasMoreOlder = response.data!.pagination?.hasMore ?? false;
              // A small first page may not fill the screen — top up so
              // scroll-to-load still works.
              _maybeFillViewport();
            }
            return InkWell(
              focusColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,

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
                        physics: BouncingScrollPhysics(),
                        // One extra trailing slot (top of the reversed list)
                        // for the "loading older messages" spinner.
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
                            // Seal-integrity signal for received media (group);
                            // deduped by message id inside the tracker.
                            trackMediaReceivedSealState(
                              messageId: data.id,
                              mediaType: data.mediaType,
                              messageType: data.messageType,
                              sealed: isMediaSealed(data.isBlurred),
                              scope: 'group',
                              file: data.file,
                            );
                          }
                          return isMine
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
                                isEdited: data.isEdited == true,
                                isForwarded: data.isForwarded == true,
                                onLongPress: (position) {
                                  _showMessageMenu(
                                    context,
                                    position,
                                    data,
                                    isMine: true,
                                  );
                                },
                                isLocal: data.isLocal == true,
                                localPath: data.localPath,
                                uploadProgress: data.uploadProgress,
                                isBlur: data.isBlurred,
                                // Reaction dot greens once ANY recipient watched
                                // it; text double-check shows only once ALL other
                                // members have read it.
                                isSeen:
                                    data.messageType == 'reaction'
                                        ? data.seenByOthers
                                        : data.seenByAll,
                                readReceiptsEnabled: _readReceiptsEnabled,
                                isHighlighted: _highlightedMessageId == data.id,
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
                                avatar: data.sender?.avatar ?? "",
                                firstName: data.sender?.firstName,
                                lastName: data.sender?.lastName,
                                time: data.createdAt ?? "",
                                file: data.file,
                                fileType: data.mediaType,
                                messageType: data.messageType,
                                // Seal media tolerating both the REST bool and
                                // realtime int forms of is_blurred.
                                isBlurred: isMediaSealed(data.isBlurred),
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
                                onReactionSuccess: (tempId, success, serverId) {
                                  // serverId is unused here: the group send is
                                  // echoed back to us and reconciles the real
                                  // id via reconcileGroupMessage.
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
                                onReply: () => _replyToMessage(data),
                                isEdited: data.isEdited == true,
                                isForwarded: data.isForwarded == true,
                                onLongPress: (position) {
                                  _showMessageMenu(
                                    context,
                                    position,
                                    data,
                                    isMine: false,
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

                    if (_editingMessage != null)
                      MessageEditBar(
                        initialText: _editingMessage!.text ?? "",
                        onCancel: _cancelEditing,
                        onSubmit: _submitEdit,
                      ),

                    if (_editingMessage == null)
                      SendMessageWidget(
                        messageController: _messageController,
                        id: widget.roomId,
                        file: selectedImage.value,
                        image: selectedImage,
                        mediaType: selectedMediaType,
                        replyToId: _replyToId,
                        type: 'image',
                        onTapMedia: () {
                          showMediaPicker(context);
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
                            // The send reported failure, but the backend may have
                            // persisted the message anyway (row saved before its
                            // best-effort broadcast/push). Removing the optimistic
                            // bubble alone made a saved message "vanish" until the
                            // user re-opened the thread, so re-sync from the server:
                            // a saved message reappears immediately, a genuinely
                            // failed one stays gone.
                            setState(() {
                              cList.removeWhere((msg) => msg.id == tempId);
                            });
                            getGroupInboxRx.getGroupInboxMessage(
                              id: widget.roomId,
                              limit: _pageSize,
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          } else if (asyncSnapshot.hasError) {
            // A failed load previously showed a blank screen; surface a
            // message and a retry that re-fetches the conversation.
            return LoadErrorRetry(
              message: "Couldn't load this conversation.",
              onRetry:
                  () => getGroupInboxRx.getGroupInboxMessage(id: widget.roomId),
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
    );
  }
}
