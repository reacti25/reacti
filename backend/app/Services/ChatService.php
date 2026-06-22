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

            $notifyData = [
                'title' => $senderName,
                'body' => $messagePreview,
                'icon' => Auth::guard('api')->user()->avatar ?? config('settings.logo'),
            ];

            $this->pushNotificationService->sendToUser($receiver, $notifyData);
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
        try {
            broadcast(new MessageReadEvent($chat->room_id, $user_id))->toOthers();
        } catch (\Throwable $e) {
            Log::error('MessageReadEvent broadcast failed', [
                'room_id' => $chat->room_id,
                'viewer_id' => $user_id,
                'error' => $e->getMessage(),
            ]);
        }

        return $chat;
    }

    /**
     * Build the conversation payload between the auth user and another user.
     *
     * Marks the other user's messages as read and finds or creates the
     * {@see Room}, regardless of mode. Each message is tagged with
     * `is_my_text` and a `should_show_blur` flag — true only for media the
     * auth user has received but not yet viewed, which drives the patent blur
     * placeholder. Also reports mutual block status.
     *
     * Supports two modes, mirroring the group thread
     * ({@see GroupMessageService::getMessages()}):
     *   - CURSOR (lazy-load): when `$limit` is provided, returns the newest
     *     `$limit` messages (id desc); `$before=<id>` fetches the next older
     *     page. One extra row is read to compute `has_more`, then dropped.
     *   - FULL (default): when `$limit` is null, returns the whole conversation
     *     (paginated with a very large page size, ordered created_at asc) —
     *     byte-for-byte the legacy response the live App Store app depends on.
     *
     * @param  int  $receiver_id  The other participant.
     * @param  int  $sender_id  The authenticated user's id.
     * @param  int|null  $limit  When non-null, enables cursor mode (clamped 1..100).
     * @param  int|string|null  $before  Cursor: only messages with `id < before`.
     * @return array{mode: string, paginator: LengthAwarePaginator|null,
     *               messages: \Illuminate\Support\Collection, has_more: bool,
     *               before: int|null, limit: int|null, receiver: User, sender: User,
     *               room: Room, is_blocked: bool, block_by_me: bool}
     */
    public function conversation($receiver_id, $sender_id, ?int $limit = null, $before = null): array
    {
        // Mark messages as read (both modes — opening the thread clears unread).
        Chat::where('receiver_id', $sender_id)
            ->where('sender_id', $receiver_id)
            ->update(['status' => 'read']);

        // Base query: both directions of the 1:1, with the same eager loads the
        // full thread has always used. Cursor and full mode share it verbatim.
        // The directional OR is wrapped in an outer where() group so the cursor's
        // `id < before` constraint ANDs against the whole pair — otherwise SQL
        // precedence (AND binds tighter than OR) would leave the sender->receiver
        // direction uncursored and the `before` page would still include newer
        // messages. Full mode is unaffected: `WHERE ((A) OR (B))` selects the
        // same rows in the same order as the previous `WHERE (A) OR (B)`.
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

        // --- Cursor (lazy-load) mode: the app opts in by sending `limit`. ---
        // Returns the newest `limit` messages (id desc); `before=<id>` fetches
        // the next older page. One extra row is read to compute `has_more`, then
        // dropped. id is the cursor (monotonic, stable) so paging stays correct
        // even as new messages arrive. Mirrors GroupMessageService::getMessages.
        if ($limit !== null) {
            $limit = max(1, min($limit, 100)); // clamp 1..100
            $hasBefore = $before !== null && $before !== '';

            $query = $base->orderBy('id', 'desc');
            if ($hasBefore) {
                $query->where('id', '<', (int) $before);
            }

            $rows = $query->limit($limit + 1)->get();
            $hasMore = $rows->count() > $limit;
            $messages = $rows->take($limit)->values(); // newest-first

            $this->tagBlurAndOwnership($messages, $sender_id);

            return $this->assembleConversation(
                $receiver_id,
                $sender_id,
                mode: 'cursor',
                paginator: null,
                messages: $messages,
                hasMore: $hasMore,
                before: $hasBefore ? (int) $before : null,
                limit: $limit,
            );
        }

        // --- Full-thread mode (default): UNCHANGED, so the live app and the
        // existing response contract are untouched. Returns the whole
        // conversation. This is the safety net; new clients use cursor mode. ---
        $perPage = 100000;
        $chat = $base->orderBy('created_at')->paginate($perPage);

        $this->tagBlurAndOwnership($chat->getCollection(), $sender_id);

        return $this->assembleConversation(
            $receiver_id,
            $sender_id,
            mode: 'full',
            paginator: $chat,
            messages: $chat->getCollection(),
            hasMore: false,
            before: null,
            limit: null,
        );
    }

    /**
     * Tag each message with `is_my_text` and `should_show_blur` (the patent
     * blur flag). Shared by the cursor and full-thread fetch paths so the
     * placeholder logic is identical in both modes.
     *
     * `should_show_blur` is true only for media the auth user RECEIVED and has
     * not yet viewed — exactly the legacy semantics; do not change it.
     *
     * @param  \Illuminate\Support\Collection  $messages  Loaded Chat models (mutated in place).
     * @param  int  $sender_id  The authenticated user's id.
     */
    private function tagBlurAndOwnership($messages, $sender_id): void
    {
        $messages->transform(function ($message) use ($sender_id) {
            $message->is_my_text = $message->sender_id === $sender_id;
            $message->should_show_blur = false;
            if ($message->receiver_id === $sender_id && $message->is_blurred && ! $message->is_viewed) {
                $message->should_show_blur = true;
            }

            return $message;
        });
    }

    /**
     * Resolve the room and block flags and assemble the conversation result
     * array shared by both modes. Keeps the room find-or-create and block
     * checks identical regardless of cursor vs full mode.
     *
     * @param  int  $receiver_id  The other participant.
     * @param  int  $sender_id  The authenticated user's id.
     * @param  string  $mode  `cursor` or `full`.
     * @param  LengthAwarePaginator|null  $paginator  Full mode only.
     * @param  \Illuminate\Support\Collection  $messages  The messages to return.
     * @param  bool  $hasMore  Whether an older page exists (cursor); always false in full mode.
     * @param  int|null  $before  The applied cursor (cursor mode only).
     * @param  int|null  $limit  The clamped page size (cursor mode only).
     * @return array<string, mixed> The full conversation payload.
     */
    private function assembleConversation(
        $receiver_id,
        $sender_id,
        string $mode,
        $paginator,
        $messages,
        bool $hasMore,
        ?int $before,
        ?int $limit,
    ): array {
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

        // Check if sender is blocked by receiver (a block in either direction)
        $is_blocked = $this->blockService->blockExistsBetween($sender_id, $receiver_id);

        // Check if sender has blocked the receiver
        $block_by_me = $this->blockService->hasBlocked($sender_id, $receiver_id);

        return [
            'mode' => $mode,
            'paginator' => $paginator,
            'messages' => $messages,
            'has_more' => $hasMore,
            'before' => $before,
            'limit' => $limit,
            'receiver' => User::select('id', 'first_name', 'last_name', 'avatar', 'last_activity_at')
                ->where('id', $receiver_id)
                ->first(),
            'sender' => User::select('id', 'first_name', 'last_name', 'avatar', 'last_activity_at')
                ->where('id', $sender_id)
                ->first(),
            'room' => $room,
            'is_blocked' => $is_blocked,
            'block_by_me' => $block_by_me,
        ];
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
        $chat = Chat::where('receiver_id', $sender_id)->where('sender_id', $receiver_id)->update(['status' => 'read']);

        return $chat;
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
            ];
        }));

        // --- Fetch groups ---
        $groupsQuery = Group::whereHas('members', fn ($q) => $q->where('user_id', $authUser->id));

        if ($keyword) {
            $groupsQuery->where('name', 'LIKE', "%{$keyword}%");
        }

        //
        $groups = collect($groupsQuery->get()->map(function ($group) {
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
