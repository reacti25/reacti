<?php

namespace App\Services;

use App\Events\MessageDeletedEvent;
use App\Events\MessageReactionEvent;
use App\Events\MessageReadEvent;
use App\Events\MessageSendEvent;
use App\Helpers\Helper;
use App\Http\Controllers\Api\Chat\ChatController;
use App\Models\Chat;
use App\Models\Group;
use App\Models\Room;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Business logic for 1:1 (direct) chat messaging.
 *
 * Extracted from {@see ChatController} so the
 * controller only validates input, applies soft-failure guard clauses, and
 * shapes the JSON response. This service is central to the patent flow:
 * {@see ChatService::send()} stores media in `normal` messages with
 * `is_blurred=true`, and {@see ChatService::markAsViewed()} performs the
 * `mark-viewed` unblur that triggers the receiver's silent reaction
 * recording. All DB writes, Pusher broadcasts, and notification fan-out are
 * reproduced verbatim from the pre-refactor controller — no behaviour change.
 */
class ChatService
{
    /** Minutes after sending during which the sender may still edit a message. */
    private const EDIT_WINDOW_MINUTES = 10;

    /**
     * @param  PushNotificationService  $pushNotificationService  Device push fan-out.
     * @param  BlockService  $blockService  Block-state queries.
     */
    public function __construct(
        private readonly PushNotificationService $pushNotificationService,
        private readonly BlockService $blockService
    ) {}

    /**
     * Create and broadcast a message in a 1:1 chat.
     *
     * Finds or creates the {@see Room} between sender and receiver, uploads
     * any attached file via {@see Helper::fileUpload()}, and inserts a
     * `chats` row. Media messages with `message_type=normal` are stored with
     * `is_blurred=true` so the patent flow can trigger on the receiver side.
     *
     * Broadcasts:
     *   - `MessageSendEvent` always (live chat list update for both sides)
     *   - `MessageReactionEvent` only when `message_type=reaction`, carrying
     *     the running reaction count chained back via `reply_to_id`
     *
     * Also fans out Firebase push notifications to the receiver's registered
     * devices (best-effort; failures are logged not thrown by the Helper).
     *
     * The caller is responsible for confirming the receiver exists and is
     * not the sender before invoking this method.
     *
     * @param  Request  $request  The incoming request (text, file, message_type, reply_to_id).
     * @param  int  $receiver_id  The user being messaged.
     * @param  int  $sender_id  The authenticated user's id.
     * @return Chat The created chat row, with relations eager-loaded.
     */
    public function send(Request $request, $receiver_id, $sender_id): Chat
    {
        // Find or create room
        $room = Room::where(function ($query) use ($receiver_id, $sender_id) {
            $query->where('user_one_id', $receiver_id)->where('user_two_id', $sender_id);
        })->orWhere(function ($query) use ($receiver_id, $sender_id) {
            $query->where('user_one_id', $sender_id)->where('user_two_id', $receiver_id);
        })->first();

        if (! $room) {
            $room = Room::create([
                'user_one_id' => $sender_id,
                'user_two_id' => $receiver_id,
            ]);
        }

        $file = null;
        if ($request->hasFile('file')) {
            $file = Helper::fileUpload($request->file('file'), 'chat', time().'_'.$request->file('file'));
        }

        // Determine message type and blur status
        $messageType = $request->input('message_type', 'normal');
        $isBlurred = false;

        // If it's a normal message with media, it should be blurred
        if ($messageType === 'normal' && $file) {
            $isBlurred = true;
        }

        $text = $request->text ?? '';

        if (! mb_check_encoding($text, 'UTF-8')) {
            $text = mb_convert_encoding($text, 'UTF-8', 'UTF-8');
        }

        $chat = Chat::create([
            'sender_id' => $sender_id,
            'receiver_id' => $receiver_id,
            'text' => $text,
            'file' => $file,
            'room_id' => $room->id,
            'status' => 'sent',
            'is_blurred' => $isBlurred,
            'is_viewed' => false,
            'message_type' => $messageType,
            'reply_to_id' => $request->reply_to_id, // New
        ]);

        // $chat->load([
        //     'sender:id,first_name,last_name,avatar,last_activity_at',
        //     'receiver:id,first_name,last_name,avatar,last_activity_at',
        //     'room:id,user_one_id,user_two_id',
        //     'replyTo.sender:id,first_name,last_name,avatar',
        // ]);

        $chat->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'receiver:id,first_name,last_name,avatar,last_activity_at',
            'room:id,user_one_id,user_two_id',
            'replyTo.sender:id,first_name,last_name,avatar',
            'replyTo.parentReply:id,text,file',
        ]);

        // The message is already persisted above; a realtime fan-out failure
        // must never fail the send (an uncaught throw would 500 the request and
        // make the sender's client drop its optimistic message — see
        // GroupMessageService::sendMessage for the full rationale). Log and go on.
        try {
            broadcast(new MessageSendEvent($chat))->toOthers();
        } catch (\Throwable $e) {
            Log::error('MessageSendEvent broadcast failed', [
                'message_id' => $chat->id,
                'room_id' => $chat->room_id,
                'error' => $e->getMessage(),
            ]);
        }

        // For reaction-type messages (the patent flow's silent video reply),
        // also fire a dedicated MessageReactionEvent. This lets a sender's
        // client surface a "your message got a reaction" indicator without
        // re-parsing every MessageSendEvent. The reaction count is the total
        // reactions chained back to the original message via reply_to_id.
        if ($messageType === 'reaction' && $chat->reply_to_id) {
            $reactionCount = Chat::where('reply_to_id', $chat->reply_to_id)
                ->where('message_type', 'reaction')
                ->count();

            try {
                broadcast(new MessageReactionEvent(
                    chatId: $chat->id,
                    roomId: $chat->room_id,
                    userId: $sender_id,
                    reaction: $chat->file,
                    reactionCounts: $reactionCount,
                ))->toOthers();
            } catch (\Throwable $e) {
                Log::error('MessageReactionEvent broadcast failed', [
                    'message_id' => $chat->id,
                    'room_id' => $chat->room_id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        // ========== NOTIFICATION PART ==========
        $receiver = User::find($receiver_id);
        if ($receiver && $receiver->firebaseTokens) {
            $senderName = Auth::guard('api')->user()->first_name.' '.Auth::guard('api')->user()->last_name;

            // Message preview create
            $messagePreview = '';
            if ($file) {
                // File type detect
                $extension = pathinfo($file, PATHINFO_EXTENSION);
                $imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
                $videoExtensions = ['mp4', 'mov', 'avi', 'mkv'];

                if (in_array(strtolower($extension), $imageExtensions)) {
                    $messagePreview = '📷 Photo';
                } elseif (in_array(strtolower($extension), $videoExtensions)) {
                    $messagePreview = '🎥 Video';
                } else {
                    $messagePreview = '📎 File';
                }
            } else {
                $messagePreview = Str::limit($text, 50);
            }

            $senderAvatar = Auth::guard('api')->user()->avatar ?? config('settings.logo');
            $notifyData = [
                'title' => $senderName,
                'body' => $messagePreview,
                'icon' => $senderAvatar,
                // Deep-link routing (all strings, per FCM). On tap the receiver
                // opens the 1:1 chat with the SENDER, so the peer id is the sender.
                'data' => [
                    'type' => 'chat_1to1',
                    'id' => (string) $sender_id,
                    'roomId' => (string) $room->id,
                    'name' => (string) $senderName,
                    'image' => (string) $senderAvatar,
                ],
            ];

            $badge = $this->unseenConversationCountForUser($receiver_id);
            $this->pushNotificationService->sendToUser($receiver, $notifyData, $badge);
        }

        return $chat;
    }

    /**
     * Forward a message's text/media into a 1:1 chat with [$receiverId].
     *
     * Reuses the original message's stored file path (no re-upload), stamps
     * `forwarded_from` with the original author, and — like a normal send —
     * seals forwarded media (`is_blurred`) so it still drives the patent
     * reaction flow, broadcasts `MessageSendEvent`, and pushes to the
     * recipient. The message is always stored as `normal` (a forwarded clip is
     * ordinary media, not a reaction).
     *
     * @param  int  $receiverId  The user being forwarded to.
     * @param  User  $authUser  The user doing the forwarding.
     * @param  string|null  $text  The original message text.
     * @param  string|null  $file  The original stored file path (or null).
     * @param  int|null  $forwardedFrom  The original author's id.
     * @return Chat The created forwarded message.
     */
    public function forwardToUser(int $receiverId, User $authUser, ?string $text, ?string $file, ?int $forwardedFrom): Chat
    {
        $senderId = $authUser->id;

        // Find or create the room (same lookup as send()).
        $room = Room::where(function ($query) use ($receiverId, $senderId) {
            $query->where('user_one_id', $receiverId)->where('user_two_id', $senderId);
        })->orWhere(function ($query) use ($receiverId, $senderId) {
            $query->where('user_one_id', $senderId)->where('user_two_id', $receiverId);
        })->first();

        if (! $room) {
            $room = Room::create([
                'user_one_id' => $senderId,
                'user_two_id' => $receiverId,
            ]);
        }

        // Forwarded media stays sealed for the recipient (patent flow).
        $isBlurred = $file !== null;

        $safeText = $text ?? '';
        if (! mb_check_encoding($safeText, 'UTF-8')) {
            $safeText = mb_convert_encoding($safeText, 'UTF-8', 'UTF-8');
        }

        $chat = Chat::create([
            'sender_id' => $senderId,
            'receiver_id' => $receiverId,
            'forwarded_from' => $forwardedFrom,
            'text' => $safeText,
            'file' => $file,
            'room_id' => $room->id,
            'status' => 'sent',
            'is_blurred' => $isBlurred,
            'is_viewed' => false,
            'message_type' => 'normal',
        ]);

        $chat->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'receiver:id,first_name,last_name,avatar,last_activity_at',
            'room:id,user_one_id,user_two_id',
        ]);

        // Persisted already — a realtime fan-out failure must not fail forward.
        try {
            broadcast(new MessageSendEvent($chat))->toOthers();
        } catch (\Throwable $e) {
            Log::error('MessageSendEvent (forward) broadcast failed', [
                'message_id' => $chat->id,
                'room_id' => $chat->room_id,
                'error' => $e->getMessage(),
            ]);
        }

        // Best-effort push to the recipient (mirrors send()). The token
        // relation is always a Collection, so a plain null-check on the user is
        // enough; sendToUser() no-ops when there are no tokens.
        $receiver = User::find($receiverId);
        if ($receiver) {
            $senderName = $authUser->first_name.' '.$authUser->last_name;
            $preview = $file ? '📎 Forwarded media' : Str::limit($safeText, 50);
            $senderAvatar = $authUser->avatar ?? config('settings.logo');
            $notifyData = [
                'title' => $senderName,
                'body' => $preview,
                'icon' => $senderAvatar,
                'data' => [
                    'type' => 'chat_1to1',
                    'id' => (string) $senderId,
                    'roomId' => (string) $room->id,
                    'name' => (string) $senderName,
                    'image' => (string) $senderAvatar,
                ],
            ];
            $badge = $this->unseenConversationCountForUser($receiverId);
            $this->pushNotificationService->sendToUser($receiver, $notifyData, $badge);
        }

        return $chat;
    }

    /**
     * Mark a media message as viewed (unblur it for the receiver).
     *
     * Second leg of the patent flow — invoked when the receiver taps the
     * blurred preview. Flips `is_blurred=false` and `is_viewed=true` on the
     * chat row, then broadcasts `MessageReadEvent($room_id, $viewer_id)` so
     * the sender's client can swap a "sent" indicator for "viewed" without
     * polling.
     *
     * The lookup is scoped by `receiver_id = current user`, so a third party
     * who guesses a message id cannot forge a viewed indicator — in that
     * case `null` is returned and the caller responds with a 404 envelope.
     *
     * @param  int  $message_id  The chat row id to mark viewed.
     * @param  int  $user_id  The authenticated user's id.
     * @return Chat|null The updated chat row, or null when not found / not addressed to the user.
     */
    public function markAsViewed($message_id, $user_id): ?Chat
    {
        $chat = Chat::where('id', $message_id)
            ->where('receiver_id', $user_id)
            ->first();

        if (! $chat) {
            return null;
        }

        // Mark as viewed (unblur)
        $chat->update([
            'is_viewed' => true,
            'is_blurred' => false,
        ]);

        // Notify the sender (and anyone else listening on the room) that the
        // message has been viewed. The patent-flow client uses this to swap
        // the "sent" indicator for "viewed" without polling. The view is
        // already persisted, so a broadcast failure must not fail the call —
        // otherwise the client treats mark-viewed as failed and the silent
        // reaction recording never fires.
        //
        // Read-receipts gating is reciprocal: withhold this "seen" signal when
        // the viewer has read receipts off. ONLY the broadcast is gated — the
        // is_viewed/is_blurred write above and the patent reaction trigger run
        // exactly as before, regardless of the toggle.
        if ($this->readReceiptsEnabled($user_id)) {
            try {
                // Carry the specific message id so the sender greens only THIS
                // reaction's dot (per-message), not every reaction in the room.
                broadcast(new MessageReadEvent($chat->room_id, $user_id, $chat->id))->toOthers();
            } catch (\Throwable $e) {
                Log::error('MessageReadEvent broadcast failed', [
                    'room_id' => $chat->room_id,
                    'viewer_id' => $user_id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return $chat;
    }

    /**
     * Whether a user currently has read receipts enabled.
     *
     * Reads the raw column (bypassing casts) and treats a missing/null value
     * as enabled, so existing rows keep today's behaviour.
     *
     * @param  int  $userId  The user whose preference to check.
     * @return bool True when the "seen" signal may be broadcast for this user.
     */
    private function readReceiptsEnabled($userId): bool
    {
        return (bool) (User::whereKey($userId)->value('read_receipts') ?? true);
    }

    /**
     * Build the full conversation payload between the auth user and another user.
     *
     * Marks the other user's messages as read, finds or creates the
     * {@see Room}, and returns the messages. Each message is tagged with
     * `is_my_text` and a `should_show_blur` flag — true only for media the
     * auth user has received but not yet viewed, which drives the patent blur
     * placeholder. Also reports mutual block status.
     *
     * Two modes, mirroring {@see GroupMessageService::getMessages()}:
     *  - **cursor** (app opts in with $limit): the newest $limit messages
     *    (id desc); $before=<id> fetches the next older page; `has_more` is
     *    computed from one extra row. `chat` is a plain Collection.
     *  - **full** (default, $limit null): the whole conversation oldest-first
     *    as today — UNCHANGED shape (`chat` stays a paginator) so the live app
     *    and the admin panel are untouched.
     *
     * @param  int  $receiver_id  The other participant.
     * @param  int  $sender_id  The authenticated user's id.
     * @param  int|null  $limit  Cursor page size (1..100); null → full mode.
     * @param  int|null  $before  Cursor: only messages with id < this (older page).
     * @return array receiver, sender, room, chat, mode, has_more, before, limit,
     *               and block flags.
     */
    public function conversation($receiver_id, $sender_id, ?int $limit = null, ?int $before = null): array
    {
        $isCursor = $limit !== null;
        $hasBefore = $before !== null;

        // Mark the peer's messages read only on the initial open — NOT when
        // paging to older history (a load-older request carries $before), so
        // scrolling up never re-marks or re-broadcasts.
        $markedRead = 0;
        if (! $hasBefore) {
            $markedRead = Chat::where('receiver_id', $sender_id)
                ->where('sender_id', $receiver_id)
                ->update(['status' => 'read']);
        }

        // Wrap the two-direction match in ONE group so a later top-level
        // condition (the cursor `id < before`) ANDs against the whole pair —
        // without the wrapper, `(dirA) OR (dirB) AND id < before` parses as
        // `dirA OR (dirB AND id < before)` and leaks the unfiltered direction.
        $base = Chat::query()
            ->where(function ($outer) use ($receiver_id, $sender_id) {
                $outer->where(function ($query) use ($receiver_id, $sender_id) {
                    $query->where('sender_id', $sender_id)->where('receiver_id', $receiver_id);
                })->orWhere(function ($query) use ($receiver_id, $sender_id) {
                    $query->where('sender_id', $receiver_id)->where('receiver_id', $sender_id);
                });
            })
            ->with([
                'sender:id,first_name,last_name,avatar,last_activity_at',
                'receiver:id,first_name,last_name,avatar,last_activity_at',
                'room:id,user_one_id,user_two_id',
                'replyTo.sender:id,first_name,last_name,avatar',
                'replyTo.parentReply:id,text,file',
            ]);

        if ($isCursor) {
            // Newest $limit messages, id desc; $before pages older. One extra
            // row tells us has_more, then is dropped. id is a stable cursor.
            $clamped = max(1, min($limit, 100));
            $query = $base->orderBy('id', 'desc');
            if ($hasBefore) {
                $query->where('id', '<', $before);
            }
            $rows = $query->limit($clamped + 1)->get();
            $hasMore = $rows->count() > $clamped;
            $messages = $rows->take($clamped)->values(); // newest-first
            $paginator = null;
            $mode = 'cursor';
        } else {
            // Full-thread mode (default): whole conversation, oldest-first,
            // paginator preserved so the admin panel / old app shape is unchanged.
            $paginator = $base->orderBy('created_at')->paginate(100000);
            $messages = $paginator->getCollection();
            $hasMore = false;
            $mode = 'full';
        }

        // Reciprocal read receipts: if the OTHER party has them off, don't reveal
        // that they read my messages (the live broadcast is already withheld;
        // this closes the same leak on fetch). Downgrade 'read' → 'sent' so the
        // double-check drops back to a single check.
        $readerReceiptsOn = $this->readReceiptsEnabled($receiver_id);

        // Transform messages (mutates the underlying collection in both modes).
        $messages->transform(function ($message) use ($sender_id, $readerReceiptsOn) {
            $message->is_my_text = $message->sender_id === $sender_id;
            if ($message->is_my_text && ! $readerReceiptsOn && $message->status === 'read') {
                $message->status = 'sent';
            }
            $message->should_show_blur = false;
            if ($message->receiver_id === $sender_id && $message->is_blurred && ! $message->is_viewed) {
                $message->should_show_blur = true;
            }

            return $message;
        });

        // Get or create room
        $room = Room::where(function ($query) use ($receiver_id, $sender_id) {
            $query->where('user_one_id', $receiver_id)->where('user_two_id', $sender_id);
        })->orWhere(function ($query) use ($receiver_id, $sender_id) {
            $query->where('user_one_id', $sender_id)->where('user_two_id', $receiver_id);
        })->first();

        if (! $room) {
            $room = Room::create([
                'user_one_id' => $sender_id,
                'user_two_id' => $receiver_id,
            ]);
        }

        // Text "seen": when the reader opens the conversation and messages were
        // actually marked read, tell the sender. This is what gives text-only
        // chats a double-check (mark-viewed only fires for media). Reciprocal —
        // withheld when the reader has read receipts off. Separate from the
        // patent mark-viewed/reaction path; a broadcast failure is non-fatal.
        if ($markedRead > 0 && $this->readReceiptsEnabled($sender_id)) {
            try {
                broadcast(new MessageReadEvent($room->id, $sender_id))->toOthers();
            } catch (\Throwable $e) {
                Log::error('MessageReadEvent (conversation) broadcast failed', [
                    'room_id' => $room->id,
                    'viewer_id' => $sender_id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        // Check if sender is blocked by receiver (a block in either direction)
        $is_blocked = $this->blockService->blockExistsBetween($sender_id, $receiver_id);

        // Check if sender has blocked the receiver
        $block_by_me = $this->blockService->hasBlocked($sender_id, $receiver_id);

        $data = [
            'receiver' => User::select('id', 'first_name', 'last_name', 'avatar', 'last_activity_at')
                ->where('id', $receiver_id)
                ->first(),
            'sender' => User::select('id', 'first_name', 'last_name', 'avatar', 'last_activity_at')
                ->where('id', $sender_id)
                ->first(),
            'room' => $room,
            // Full mode keeps the paginator (admin panel / old app read this);
            // cursor mode returns the plain newest-first Collection.
            'chat' => $isCursor ? $messages : $paginator,
            'mode' => $mode,
            'has_more' => $hasMore,
            'before' => $hasBefore ? $before : null,
            'limit' => $isCursor ? $clamped : null,
            'is_blocked' => $is_blocked,
            'block_by_me' => $block_by_me,
        ];

        return $data;
    }

    /**
     * Mark every message from a given sender to the auth user as read.
     *
     * The caller is responsible for confirming the other user exists and is
     * not the auth user before invoking this method.
     *
     * @param  int  $receiver_id  The other user whose messages (sent to the
     *                            auth user) get marked read.
     * @param  int  $sender_id  The authenticated user's id.
     * @return int The number of `chats` rows updated.
     */
    public function seenAll($receiver_id, $sender_id): int
    {
        $marked = Chat::where('receiver_id', $sender_id)->where('sender_id', $receiver_id)->update(['status' => 'read']);

        // Live text double-check: tell the sender their messages were read even
        // when the reader is already sitting in the chat — the conversation
        // fetch only marks read on open, so a message arriving via push while
        // the reader is present would otherwise never upgrade the sender's tick
        // until a re-fetch. Reciprocal — withheld when the reader has receipts
        // off. Non-fatal on broadcast failure. Separate from the mark-viewed
        // patent path (this is text status only).
        if ($marked > 0 && $this->readReceiptsEnabled($sender_id)) {
            $room = Room::where(function ($query) use ($receiver_id, $sender_id) {
                $query->where('user_one_id', $receiver_id)->where('user_two_id', $sender_id);
            })->orWhere(function ($query) use ($receiver_id, $sender_id) {
                $query->where('user_one_id', $sender_id)->where('user_two_id', $receiver_id);
            })->first();

            if ($room) {
                try {
                    broadcast(new MessageReadEvent($room->id, $sender_id))->toOthers();
                } catch (\Throwable $e) {
                    Log::error('MessageReadEvent (seenAll) broadcast failed', [
                        'room_id' => $room->id,
                        'viewer_id' => $sender_id,
                        'error' => $e->getMessage(),
                    ]);
                }
            }
        }

        return $marked;
    }

    /**
     * Mark a single received chat message as read.
     *
     * Scoped by `receiver_id = auth user`, so a caller can only mark
     * messages addressed to themselves.
     *
     * @param  int  $chat_id  The chat row to mark read.
     * @param  int  $sender_id  The authenticated user's id.
     * @return int The number of `chats` rows updated.
     */
    public function seenSingle($chat_id, $sender_id): int
    {
        $chat = Chat::where('id', $chat_id)->where('receiver_id', $sender_id)->update(['status' => 'read']);

        return $chat;
    }

    /**
     * Get (or lazily create) the 1:1 room with another user.
     *
     * The caller is responsible for confirming the other user exists and is
     * not the auth user before invoking this method.
     *
     * @param  int  $receiver_id  The other participant.
     * @param  int  $sender_id  The authenticated user's id.
     * @return Room The room with both users eager-loaded.
     */
    public function room($receiver_id, $sender_id): Room
    {
        $room = Room::with(['userOne:id , first_name , last_name , email , avatar , last_activity_at', 'userTwo: id , first_name , last_name , avatar , last_activity_at'])
            ->where(function ($query) use ($receiver_id, $sender_id) {
                $query->where('user_one_id', $receiver_id)->where('user_two_id', $sender_id);
            })->orWhere(function ($query) use ($receiver_id, $sender_id) {
                $query->where('user_one_id', $sender_id)->where('user_two_id', $receiver_id);
            })->first();

        if (! $room) {
            $room = Room::create([
                'user_one_id' => $sender_id,
                'user_two_id' => $receiver_id,
            ]);
        }

        return $room;
    }

    /**
     * Search users by name or email for starting a chat.
     *
     * Matches the keyword against first name, last name, or email and
     * excludes the auth user from the results.
     *
     * @param  string|null  $keyword  The search keyword.
     * @param  int|null  $user_id  The authenticated user's id to exclude.
     * @return Collection Matching users.
     */
    public function search($keyword, $user_id)
    {
        $users = User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')
            ->where('id', '!=', $user_id)
            ->where('first_name', 'LIKE', "%{$keyword}%")->orWhere('last_name', 'LIKE', "%{$keyword}%")->orWhere('email', 'LIKE', "%{$keyword}%")
            ->get();

        return $users;
    }

    /**
     * Delete the entire conversation with another user.
     *
     * Soft-deletes every message in the shared room, then deletes the room
     * itself. Returns `false` when no room exists between the two users so
     * the caller can respond with a 404 envelope.
     *
     * @param  int  $receiver_id  The other participant.
     * @param  int  $sender_id  The authenticated user's id.
     * @return bool True when a conversation was deleted, false when none exists.
     */
    public function deleteChat($receiver_id, $sender_id): bool
    {
        // Find the room between these two users
        $room = Room::where(function ($query) use ($receiver_id, $sender_id) {
            $query->where('user_one_id', $sender_id)->where('user_two_id', $receiver_id);
        })->orWhere(function ($query) use ($receiver_id, $sender_id) {
            $query->where('user_one_id', $receiver_id)->where('user_two_id', $sender_id);
        })->first();

        if (! $room) {
            return false;
        }

        // Soft delete all messages in this room
        Chat::where('room_id', $room->id)->delete();

        // Delete the room itself
        $room->delete();

        return true;
    }

    /**
     * Delete a single chat message (soft-delete on the `chats` row).
     *
     * The auth user must be either the sender or receiver of the message —
     * anyone else gets a `0` result so the caller responds with a 404
     * envelope. On a successful delete, broadcasts `MessageDeletedEvent
     * ($chatId, $roomId, 'for_everyone')` so listening clients can remove
     * the row from their conversation view without polling.
     *
     * @param  int  $message_id  The chat row to delete.
     * @param  User  $authUser  The authenticated user.
     * @return array{0: int, 1: Chat|null} [deleted-count, the resolved chat row].
     */
    public function deleteMessage($message_id, User $authUser): array
    {
        // Capture the room before deletion so we can broadcast on it.
        $chat = Chat::where('id', $message_id)
            ->where(function ($query) use ($authUser) {
                $query->where('sender_id', $authUser->id)
                    ->orWhere('receiver_id', $authUser->id);
            })
            ->first();

        $deleted = $chat ? $chat->delete() : 0;

        if ($deleted) {
            broadcast(new MessageDeletedEvent(
                chatId: $chat->id,
                roomId: $chat->room_id,
                deleteType: 'for_everyone',
            ))->toOthers();
        }

        return [$deleted, $chat];
    }

    /**
     * Edit the text of the auth user's own 1:1 message, within the window.
     *
     * Only the sender may edit, only within {@see self::EDIT_WINDOW_MINUTES}
     * minutes of sending, and reaction clips (which have no editable body) are
     * refused. On success the text is replaced, `edited_at` is stamped, and the
     * message is returned with its relations loaded for {@see ChatResource}.
     * Peers pick up the edit on their next conversation fetch (no broadcast).
     *
     * @param  int  $message_id  The chat row to edit.
     * @param  string  $text  The new message text.
     * @param  User  $authUser  The authenticated user (must be the sender).
     * @return Chat|string The updated message, or a failure reason:
     *                     `'not_found'` (missing / not owner / reaction) or
     *                     `'expired'` (past the edit window).
     */
    public function editMessage(int $message_id, string $text, User $authUser): Chat|string
    {
        $chat = Chat::where('id', $message_id)
            ->where('sender_id', $authUser->id)
            ->first();

        // Missing, not the sender's, or a reaction clip (no editable text).
        if (! $chat || $chat->message_type === 'reaction') {
            return 'not_found';
        }

        if ($chat->created_at->lt(now()->subMinutes(self::EDIT_WINDOW_MINUTES))) {
            return 'expired';
        }

        $chat->text = $text;
        $chat->edited_at = now();
        $chat->save();

        // ChatResource reads sender/receiver/room unconditionally, so load them.
        $chat->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'receiver:id,first_name,last_name,avatar,last_activity_at',
            'room:id,user_one_id,user_two_id',
            'replyTo.sender:id,first_name,last_name,avatar',
            'replyTo.parentReply:id,text,file',
        ]);

        return $chat;
    }

    /**
     * Build the unified chat list of 1:1 conversations and groups.
     *
     * Collects users the auth user has exchanged messages with plus all
     * groups they belong to, attaches each entry's last message and
     * metadata, merges and sorts the two sets by last-message time, and
     * paginates the result manually.
     *
     * @param  Request  $request  The incoming request (used for the paginator path/query).
     * @param  User  $authUser  The authenticated user.
     * @param  string|null  $keyword  Optional keyword filter.
     * @param  int|null  $perPage  Page size (default 10).
     * @return LengthAwarePaginator The paginated combined chat list.
     */
    /**
     * Count the auth user's unseen messages in a 1:1 conversation.
     *
     * "Unseen" folds the three Reacti signals into one count, reusing the
     * existing per-message state (no parallel tracking): unread text
     * (`status != read`), unopened media (`is_blurred` and not `is_viewed`),
     * and unwatched reactions (`message_type = reaction` and not `is_viewed`).
     * A row matching several branches is counted once.
     *
     * @param  int  $authUserId  The viewer.
     * @param  int  $otherUserId  The conversation partner (message sender).
     * @return int Number of unseen messages addressed to the auth user.
     */
    private function unreadCountForUser(int $authUserId, int $otherUserId): int
    {
        return Chat::where('receiver_id', $authUserId)
            ->where('sender_id', $otherUserId)
            ->where(function ($q) {
                $q->where('status', '!=', 'read')
                    ->orWhere(function ($q2) {
                        $q2->where('is_blurred', true)->where('is_viewed', false);
                    })
                    ->orWhere(function ($q2) {
                        $q2->where('message_type', 'reaction')->where('is_viewed', false);
                    });
            })
            ->count();
    }

    /**
     * Count the auth user's unseen messages in a group.
     *
     * Counts a message from another member when EITHER it is unread (no
     * `reads` row for this user — the same predicate
     * {@see GroupMessageService::markAsRead()} uses) OR it is still-sealed media
     * for this user (`messageStatus` is_blurred and not is_viewed). The latter
     * is why a group with unopened media stays "Unseen" even after the thread
     * has been opened — mirroring the 1:1 count. The user's own messages never
     * count.
     *
     * @param  int  $authUserId  The viewer.
     * @param  Group  $group  The group to count within.
     * @return int Number of unseen group messages for the auth user.
     */
    private function unreadCountForGroup(int $authUserId, Group $group): int
    {
        return $group->messages()
            ->where('sender_id', '!=', $authUserId)
            ->where(function ($q) use ($authUserId) {
                // Unread text: no read receipt from this user. OR unopened media:
                // the per-user status row is still sealed (is_blurred, not
                // is_viewed) — so a group with sealed media stays "Unseen" even
                // after the thread has been opened, matching the 1:1 count.
                $q->whereDoesntHave('reads', function ($r) use ($authUserId) {
                    $r->where('user_id', $authUserId);
                })->orWhereHas('messageStatus', function ($s) use ($authUserId) {
                    $s->where('user_id', $authUserId)
                        ->where('is_blurred', true)
                        ->where('is_viewed', false);
                });
            })
            ->count();
    }

    /**
     * Count the CONVERSATIONS (not messages) with anything unseen for a user —
     * the app-icon badge number.
     *
     * Two queries, reusing the same "unseen" predicates as the per-conversation
     * counts above: distinct 1:1 partners who sent an unseen message, plus
     * groups holding an unseen message for this user. A conversation with
     * several unseen items still counts once.
     *
     * @param  int  $authUserId  The recipient whose badge is wanted.
     * @return int Number of conversations with anything unseen.
     */
    public function unseenConversationCountForUser(int $authUserId): int
    {
        // 1:1: distinct senders with an unseen message addressed to this user
        // (same predicate as unreadCountForUser).
        $directCount = Chat::where('receiver_id', $authUserId)
            ->where(function ($q) {
                $q->where('status', '!=', 'read')
                    ->orWhere(function ($q2) {
                        $q2->where('is_blurred', true)->where('is_viewed', false);
                    })
                    ->orWhere(function ($q2) {
                        $q2->where('message_type', 'reaction')->where('is_viewed', false);
                    });
            })
            ->distinct()
            ->count('sender_id');

        // Groups the user belongs to that hold an unseen message for them (same
        // predicate as unreadCountForGroup).
        $groupCount = Group::whereHas('members', fn ($q) => $q->where('user_id', $authUserId))
            ->whereHas('messages', function ($q) use ($authUserId) {
                $q->where('sender_id', '!=', $authUserId)
                    ->where(function ($qq) use ($authUserId) {
                        $qq->whereDoesntHave('reads', fn ($r) => $r->where('user_id', $authUserId))
                            ->orWhereHas('messageStatus', fn ($s) => $s->where('user_id', $authUserId)
                                ->where('is_blurred', true)
                                ->where('is_viewed', false));
                    });
            })
            ->count();

        return $directCount + $groupCount;
    }

    // ponytail: listCombined already runs per-row queries (last message, room,
    // member count) — adding one unread count per row keeps that existing N+1
    // shape. Fine at current per-page sizes; batch into grouped subqueries only
    // if the chat list ever pages large.
    public function listCombined(Request $request, User $authUser, $keyword, $perPage): LengthAwarePaginator
    {
        // --- Fetch one-to-one chat users ---
        $usersQuery = User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')
            ->where('id', '!=', $authUser->id)
            ->where(function ($query) use ($authUser) {
                $query->whereHas('senders', fn ($q) => $q->where('receiver_id', $authUser->id))
                    ->orWhereHas('receivers', fn ($q) => $q->where('sender_id', $authUser->id));
            });

        if ($keyword) {
            $usersQuery->where(function ($q) use ($keyword) {
                $q->where('first_name', 'LIKE', "%{$keyword}%")
                    ->orWhere('last_name', 'LIKE', "%{$keyword}%")
                    ->orWhere('email', 'LIKE', "%{$keyword}%");
            });
        }

        // @var widens the precise per-key object shape so the later merge() with
        // the group collection type-checks (PHPStan infers conflicting literal
        // shapes — `type: 'single'` vs `'group'` — otherwise).
        /** @var \Illuminate\Support\Collection<int, \stdClass> $users */
        $users = collect($usersQuery->get()->map(function ($user) use ($authUser) {
            $lastChat = Chat::where(function ($query) use ($user, $authUser) {
                $query->where('sender_id', $authUser->id)
                    ->where('receiver_id', $user->id);
            })
                ->orWhere(function ($query) use ($user, $authUser) {
                    $query->where('sender_id', $user->id)
                        ->where('receiver_id', $authUser->id);
                })
                ->latest()
                ->first();

            $room = Room::firstOrCreate([
                'user_one_id' => min($authUser->id, $user->id),
                'user_two_id' => max($authUser->id, $user->id),
            ]);

            return (object) [
                'type' => 'single',
                'room_id' => $room->id,
                'id' => $user->id,
                'name' => trim("{$user->first_name} {$user->last_name}"),
                'avatar' => $user->avatar ? asset($user->avatar) : asset('default/default_image.jpg'),
                // 'last_message' => $lastChat?->text,
                'last_message' => $lastChat?->text,
                'last_message_file' => $lastChat?->file,
                'last_message_time' => $lastChat?->created_at,
                'is_active' => $user->last_activity_at && $user->last_activity_at->gt(now()->subMinutes(5)),
                'member_count' => null,
                'unread_count' => $this->unreadCountForUser($authUser->id, $user->id),
            ];
        }));

        // --- Fetch groups ---
        $groupsQuery = Group::whereHas('members', fn ($q) => $q->where('user_id', $authUser->id));

        if ($keyword) {
            $groupsQuery->where('name', 'LIKE', "%{$keyword}%");
        }

        //
        /** @var \Illuminate\Support\Collection<int, \stdClass> $groups */
        $groups = collect($groupsQuery->get()->map(function ($group) use ($authUser) {
            $lastMessage = $group->messages()->latest()->first();

            return (object) [
                'type' => 'group',
                'room_id' => $group->id,
                'id' => $group->id,
                'name' => $group->name,
                'avatar' => $group->avatar ? asset($group->avatar) : asset('default/default_group.jpg'),
                // 'last_message' => $lastMessage?->text,
                'last_message' => $lastMessage?->text,
                'last_message_file' => $lastMessage?->file,
                'last_message_time' => $lastMessage?->created_at,
                'is_active' => false,
                'member_count' => $group->members()->count(),
                'unread_count' => $this->unreadCountForGroup($authUser->id, $group),
            ];
        }));

        // --- Merge + sort ---
        $combined = $users->merge($groups)
            ->sortByDesc(fn ($chat) => $chat->last_message_time)
            ->values();

        // --- Manual pagination ---
        $currentPage = LengthAwarePaginator::resolveCurrentPage();
        $pagedData = $combined->slice(($currentPage - 1) * $perPage, $perPage)->values();

        $paginator = new LengthAwarePaginator(
            $pagedData,
            $combined->count(),
            $perPage,
            $currentPage,
            ['path' => $request->url(), 'query' => $request->query()]
        );

        return $paginator;
    }
}
