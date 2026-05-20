<?php

namespace App\Http\Controllers\Api\Chat;

use App\Http\Controllers\Controller;
use App\Http\Resources\ChatMessageResource;
use App\Http\Resources\ChatResource;
use App\Http\Resources\CombinedChatCollection;
use App\Models\User;
use App\Services\ChatService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

/**
 * Handles 1:1 (direct) chat messaging for the API.
 *
 * Backs the authenticated `auth/chat` routes: sending messages, viewing
 * conversations, the combined chat list, seen/read receipts, deleting
 * messages or whole conversations, and user search. This controller is
 * central to the patent flow — media in a `normal` message is stored
 * `is_blurred`, and `markAsViewed()` is the `mark-viewed` endpoint that
 * unblurs it and triggers the receiver's silent reaction recording.
 *
 * This is a thin controller — it validates input, applies soft-failure
 * guard clauses, and shapes responses; all business logic lives in
 * {@see ChatService}.
 */
class ChatController extends Controller
{
    use ApiResponse;

    /**
     * @param  ChatService  $chatService  Direct-chat messaging business logic.
     */
    public function __construct(private readonly ChatService $chatService)
    {
        parent::__construct();
    }

    /**
     * Send a message in a 1:1 chat.
     *
     * Validates the request and rejects an invalid/self receiver, then
     * delegates to {@see ChatService::send()} which finds or creates the
     * `Room`, stores the `chats` row (media `normal` messages get
     * `is_blurred=true`), broadcasts `MessageSendEvent` (and
     * `MessageReactionEvent` for reaction messages), and fans out Firebase
     * push notifications.
     *
     * @param  Request  $request  Body: text, file, message_type, reply_to_id
     * @param  int  $receiver_id  URL param: the user being messaged
     */
    public function send(Request $request, $receiver_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'text' => 'nullable|string|max:1000',
            // Reject any upload that isn't an image or short video; a
            // .php / .svg with no extension check is stored XSS / RCE.
            'file' => 'nullable|file|mimes:jpg,jpeg,png,gif,mp4,mov,webm|max:51200',
            'message_type' => 'nullable|in:normal,reaction', // New field
            'reply_to_id' => 'nullable|exists:chats,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $sender_id = Auth::guard('api')->id();
        $receiver_exist = User::where('id', $receiver_id)->first();

        if (! $receiver_exist || $receiver_id == $sender_id) {
            return response()->json([
                'success' => false,
                'message' => 'User not found or cannot chat with yourself',
                'data' => [],
                'code' => 200,
            ]);
        }

        $chat = $this->chatService->send($request, $receiver_id, $sender_id);

        return response()->json([
            'success' => true,
            'message' => 'Message Sent Successfully.',
            'data' => ['chat' => new ChatResource($chat)],
            'code' => 200,
        ]);
    }

    /**
     * Mark a media message as viewed (unblur it for the receiver).
     *
     * This is the second leg of the patent flow — the client calls
     * this when the user taps the blurred preview. Delegates to
     * {@see ChatService::markAsViewed()} which flips `is_blurred=false`
     * and `is_viewed=true` on the chat row, then broadcasts
     * `MessageReadEvent($room_id, $viewer_id)` so the sender's client can
     * swap a "sent" indicator for "viewed" without polling.
     *
     * Scoped by `receiver_id = current user`, so a third party who
     * guesses a message id can't forge a viewed indicator → 404.
     *
     * @param  int  $message_id  The chat row id to mark viewed.
     */
    public function markAsViewed($message_id): JsonResponse
    {
        $user_id = Auth::guard('api')->id();

        $chat = $this->chatService->markAsViewed($message_id, $user_id);

        if (! $chat) {
            return response()->json([
                'success' => false,
                'message' => 'Message not found',
                'code' => 404,
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Message marked as viewed',
            'data' => ['chat' => $chat],
            'code' => 200,
        ]);
    }

    /**
     * Get the full conversation between the auth user and another user.
     *
     * Delegates to {@see ChatService::conversation()} which marks the
     * other user's messages as read, finds or creates the `Room`, and
     * returns all messages (paginated with a very large page size). Each
     * message is tagged with `is_my_text` and a `should_show_blur` flag —
     * true only for media the auth user has received but not yet viewed,
     * which is what drives the patent blur placeholder. Also reports
     * mutual block status.
     *
     * @param  int  $receiver_id  URL param: the other participant
     * @return JsonResponse receiver, sender, room, chat messages,
     *                      pagination, and block flags
     */
    public function conversation($receiver_id): JsonResponse
    {
        $sender_id = Auth::guard('api')->id();

        $result = $this->chatService->conversation($receiver_id, $sender_id);

        $chat = $result['chat'];

        $data = [
            'receiver' => $result['receiver'],
            'sender' => $result['sender'],
            'room' => $result['room'],
            'chat' => ChatMessageResource::collection($chat->items()),
            'pagination' => [
                'total' => $chat->total(),
                'current_page' => $chat->currentPage(),
                'last_page' => $chat->lastPage(),
                'per_page' => $chat->perPage(),
            ],
            'is_blocked' => $result['is_blocked'],
            'block_by_me' => $result['block_by_me'],
        ];

        return response()->json([
            'success' => true,
            'message' => 'Messages retrieved successfully',
            'data' => $data,
            'code' => 200,
        ]);
    }

    /**
     * Mark every message from a given sender to the auth user as read.
     *
     * Rejects an invalid/self user, then delegates the update to
     * {@see ChatService::seenAll()}.
     *
     * @param  int  $receiver_id  URL param: the other user whose messages
     *                            (sent to the auth user) get marked read
     * @return JsonResponse Success, or a soft failure if the user is
     *                      invalid or is the auth user themselves
     */
    public function seenAll($receiver_id): JsonResponse
    {
        $sender_id = Auth::guard('api')->id();

        $receiver_exist = User::where('id', $receiver_id)->first();

        if (! $receiver_exist || $receiver_id == $sender_id) {
            return response()->json(['success' => false, 'message' => 'User not found or cannot chat with this user.', 'data' => [], 'code' => 200]);
        }

        $chat = $this->chatService->seenAll($receiver_id, $sender_id);

        $data = [
            'chat' => $chat,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Message Seen Successfully.',
            'data' => $data,
            'code' => 200,
        ]);
    }

    /**
     * Mark a single received chat message as read.
     *
     * Delegates to {@see ChatService::seenSingle()}. Scoped by
     * `receiver_id = auth user`, so a caller can only mark messages
     * addressed to themselves.
     *
     * @param  int  $chat_id  URL param: the chat row to mark read
     * @return JsonResponse Success response
     */
    public function seenSingle($chat_id): JsonResponse
    {
        $sender_id = Auth::guard('api')->id();

        $chat = $this->chatService->seenSingle($chat_id, $sender_id);

        $data = [
            'chat' => $chat,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Message Seen Successfully',
            'data' => $data,
            'code' => 200,
        ]);
    }

    /**
     * Get (or lazily create) the 1:1 room with another user.
     *
     * Rejects an invalid/self target, then delegates to
     * {@see ChatService::room()}.
     *
     * @param  int  $receiver_id  URL param: the other participant
     * @return JsonResponse The room with both users
     *                      eager-loaded, or a soft failure
     *                      for an invalid/self target
     */
    public function room($receiver_id)
    {
        $sender_id = Auth::guard('api')->id();

        $receiver_exist = User::where('id', $receiver_id)->first();

        if (! $receiver_exist || $receiver_id == $sender_id) {
            return response()->json(['success' => false, 'message' => 'User not found or cannot chat with yourself.', 'data' => [], 'code' => 200]);
        }

        $room = $this->chatService->room($receiver_id, $sender_id);

        $data = [
            'room' => $room,
        ];

        return response()->json(['success' => true, 'message' => 'Group retrieved successfully.', 'data' => $data, 'code' => 200]);
    }

    /**
     * Search users by name or email for starting a chat.
     *
     * Delegates to {@see ChatService::search()}, which matches the keyword
     * against first name, last name, or email and excludes the auth user.
     *
     * @param  Request  $request  Query: keyword
     * @return JsonResponse Matching users (id, name, email, avatar)
     */
    public function search(Request $request): JsonResponse
    {
        $user_id = Auth::id();

        $keyword = $request->get('keyword');
        $users = $this->chatService->search($keyword, $user_id);

        $data = [
            'users' => $users,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Chat retrieved successfully',
            'data' => $data,
        ], 200);
    }

    /**
     * Delete the entire conversation with another user.
     *
     * Delegates to {@see ChatService::deleteChat()}, which soft-deletes
     * every message in the shared room and then deletes the room itself.
     *
     * @param  int  $receiver_id  URL param: the other participant
     * @return JsonResponse Success, or 404 if no conversation exists
     */
    public function deleteChat($receiver_id): JsonResponse
    {
        $sender_id = Auth::guard('api')->id();

        $deleted = $this->chatService->deleteChat($receiver_id, $sender_id);

        if (! $deleted) {
            return response()->json([
                'success' => false,
                'message' => 'Conversation not found',
                'data' => [],
                'code' => 404,
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Conversation deleted successfully',
            'data' => [],
            'code' => 200,
        ]);
    }

    /**
     * Delete a single chat message (soft-delete on the `chats` row).
     *
     * Validates the request, then delegates to
     * {@see ChatService::deleteMessage()}. The auth user must be either
     * the sender or receiver of the message — anyone else gets 404. The
     * service broadcasts `MessageDeletedEvent($chatId, $roomId,
     * 'for_everyone')` on a successful delete so listening clients can
     * remove the row from their conversation view without polling.
     *
     * Validation:
     *   message_id  required, exists:chats,id
     *
     * @param  Request  $request  Body: message_id (the chat row to delete)
     */
    public function deleteMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'message_id' => 'required|exists:chats,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null,
                'code' => 422,
            ], 422);
        }

        $authUser = Auth::guard('api')->user();

        [$deleted, $chat] = $this->chatService->deleteMessage($request->message_id, $authUser);

        if ($deleted) {
            return response()->json([
                'success' => true,
                'message' => 'Message deleted successfully',
                'data' => ['deleted_count' => $deleted],
                'code' => 200,
            ]);
        }

        return response()->json([
            'success' => false,
            'message' => 'Message not found or you do not have permission to delete it',
            'data' => null,
            'code' => 404,
        ], 404);
    }

    /**
     * Build the unified chat list of 1:1 conversations and groups.
     *
     * Delegates to {@see ChatService::listCombined()}, which collects users
     * the auth user has exchanged messages with plus all groups they belong
     * to, attaches each entry's last message and metadata, merges and sorts
     * the two sets by last-message time, and paginates the result manually.
     *
     * @param  Request  $request  Query: keyword (optional), per_page
     * @return JsonResponse Paginated CombinedChatCollection
     */
    public function listCombined(Request $request): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $keyword = $request->get('keyword');
        $perPage = $request->get('per_page', 10);

        $paginator = $this->chatService->listCombined($request, $authUser, $keyword, $perPage);

        return $this->success(
            new CombinedChatCollection($paginator),
            'Combined chat list retrieved successfully.'
        );
    }
}
