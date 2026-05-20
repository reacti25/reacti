<?php

namespace App\Http\Controllers\Api\Chat\V2;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\Chat\V2\ChatResource;
use App\Http\Resources\ChatMessageResource;
use App\Http\Resources\CombinedChatCollection;
use App\Services\SingleChatConversationService;
use App\Services\SingleChatMessageService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

/**
 * V2 controller for 1:1 (direct) chat messaging.
 *
 * A revised take on ChatController for the `auth/chat/v2` routes:
 * uploads media to S3 (with rollback on failure), caches the combined
 * chat list, and adds forwarding and typing indicators. Like V1, it
 * stores media in `normal` messages as `is_blurred` and exposes a
 * `markAsViewed()` mark-viewed endpoint for the patent flow.
 *
 * This is a thin controller — it validates input, resolves the
 * authenticated user, applies soft-failure guard clauses, and shapes
 * responses; all business logic lives in {@see SingleChatMessageService}
 * (message lifecycle) and {@see SingleChatConversationService}
 * (conversation reading/browsing).
 * Expected business-rule failures surface as {@see ApiException} and are
 * mapped onto the {@see ApiResponse::error()} envelope.
 */
class SingleChatController extends Controller
{
    use ApiResponse;

    /**
     * @param  SingleChatMessageService  $singleChatMessageService  V2 direct-chat message lifecycle business logic.
     * @param  SingleChatConversationService  $singleChatConversationService  V2 direct-chat conversation reading/browsing business logic.
     */
    public function __construct(
        private readonly SingleChatMessageService $singleChatMessageService,
        private readonly SingleChatConversationService $singleChatConversationService
    ) {
        parent::__construct();
    }

    /**
     * Send a 1:1 message with S3 media upload and real-time delivery.
     *
     * Validates the request, then delegates to {@see SingleChatMessageService::send()}
     * which rejects self-chat and blocked pairs, uploads media to S3, creates
     * the `chats` row inside a transaction (with S3 rollback on failure),
     * stores media `normal` messages as `is_blurred` for the patent flow,
     * broadcasts `MessageSendEvent`, sends a push, and invalidates both
     * users' cached chat lists.
     *
     * @param  Request  $request  Body: text, file, message_type
     *                            (normal|reaction|reply), reply_to_id
     * @param  int  $receiver_id  URL param: the user being messaged
     * @return JsonResponse The created chat as ChatResource, or 400
     *                      (invalid/self), 403 (blocked), 422, 500
     */
    public function send(Request $request, $receiver_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'text' => 'nullable|string|max:5000',
            // Reject any upload that isn't an image or short video; a
            // .php / .svg with no mime check is stored XSS / RCE.
            'file' => 'nullable|file|mimes:jpg,jpeg,png,gif,mp4,mov,webm|max:102400',
            'message_type' => 'nullable|in:normal,reaction,reply',
            'reply_to_id' => 'nullable|exists:chats,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'code' => 422,
            ], 422);
        }

        try {
            [$outcome, $chat, $errorResponse] = $this->singleChatMessageService->send($request, $receiver_id);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status(),
            ], $e->status());
        }

        // A 500-class failure (S3 upload or transaction) returns the verbatim
        // error envelope the original controller produced.
        if ($outcome === 'error') {
            return response()->json($errorResponse, 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Message sent successfully',
            'data' => ['chat' => new ChatResource($chat)],
            'code' => 200,
        ]);
    }

    /**
     * Mark a media message as viewed (unblur it for the receiver).
     *
     * The V2 patent-flow `mark-viewed` endpoint — delegates to
     * {@see SingleChatMessageService::markAsViewed()} which flips `is_blurred`
     * off and `is_viewed` on. Scoped by `receiver_id = auth user`, so
     * only the intended recipient can unblur it (others get 404).
     *
     * @param  Request  $request  Unused; present for route signature.
     * @param  int  $message_id  URL param: the chat row to mark viewed
     * @return JsonResponse The updated chat as ChatResource, or 404 if
     *                      the message does not belong to the auth user
     */
    public function markAsViewed(Request $request, $message_id): JsonResponse
    {
        try {
            $chat = $this->singleChatMessageService->markAsViewed($message_id);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status(),
            ], $e->status());
        }

        return response()->json([
            'success' => true,
            'message' => 'Message marked as viewed',
            'data' => ['chat' => new ChatResource($chat)],
            'code' => 200,
        ]);
    }

    /**
     * Get the conversation with a user, paginated newest-first.
     *
     * Delegates to {@see SingleChatConversationService::conversation()} which
     * bulk-marks the other user's messages as read, finds or creates the
     * room, and returns a page of messages. Each is tagged with
     * `is_my_text` and `should_show_blur` (true only for unviewed media
     * the auth user received — drives the patent blur placeholder). Also
     * reports mutual block status.
     *
     * @param  int  $receiver_id  URL param: the other participant
     * @return JsonResponse receiver, sender, room, chat, pagination,
     *                      and block flags; 404 for an invalid target
     */
    public function conversation($receiver_id): JsonResponse
    {
        try {
            $result = $this->singleChatConversationService->conversation($receiver_id);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status(),
            ], $e->status());
        }

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
                'from' => $chat->firstItem(),
                'to' => $chat->lastItem(),
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
     * Delegates to {@see SingleChatMessageService::seenAll()}.
     *
     * @param  int  $receiver_id  URL param: the sender whose messages get read
     * @return JsonResponse Success with updated count, or 400 for an
     *                      invalid / self target
     */
    public function seenAll($receiver_id): JsonResponse
    {
        try {
            $updated = $this->singleChatMessageService->seenAll($receiver_id);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status(),
            ], $e->status());
        }

        return response()->json([
            'success' => true,
            'message' => 'All messages marked as read',
            'data' => ['updated_count' => $updated],
            'code' => 200,
        ]);
    }

    /**
     * Mark a single received message as read.
     *
     * Delegates to {@see SingleChatMessageService::seenSingle()}. Scoped by
     * `receiver_id = auth user`; a no-op or unknown id yields 404.
     *
     * @param  int  $chat_id  URL param: the chat row to mark read
     * @return JsonResponse Success, or 404 if not found / already read
     */
    public function seenSingle($chat_id): JsonResponse
    {
        try {
            $this->singleChatMessageService->seenSingle($chat_id);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status(),
            ], $e->status());
        }

        return response()->json([
            'success' => true,
            'message' => 'Message marked as read',
            'code' => 200,
        ]);
    }

    /**
     * Get (or lazily create) the 1:1 room with another user.
     *
     * Delegates to {@see SingleChatConversationService::room()}.
     *
     * @param  int  $receiver_id  URL param: the other participant
     * @return JsonResponse The room with both users eager-loaded, or
     *                      400 for an invalid / self target
     */
    public function room($receiver_id): JsonResponse
    {
        try {
            $room = $this->singleChatConversationService->room($receiver_id);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status(),
            ], $e->status());
        }

        return response()->json([
            'success' => true,
            'message' => 'Room retrieved successfully',
            'data' => ['room' => $room],
            'code' => 200,
        ]);
    }

    /**
     * Search users by name, email, or username (max 50 results).
     *
     * Delegates to {@see SingleChatConversationService::search()}, which excludes the
     * auth user from results.
     *
     * @param  Request  $request  Query: keyword (required)
     * @return JsonResponse Matching users, or 400 if no keyword given
     */
    public function search(Request $request): JsonResponse
    {
        $keyword = $request->get('keyword');

        try {
            $users = $this->singleChatConversationService->search($keyword);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status(),
            ], $e->status());
        }

        return response()->json([
            'success' => true,
            'message' => 'Search completed successfully',
            'data' => ['users' => $users],
            'code' => 200,
        ]);
    }

    /**
     * Delete the entire conversation with another user.
     *
     * Delegates to {@see SingleChatConversationService::deleteChat()}, which inside a
     * transaction removes every S3-hosted file in the room, soft-deletes
     * all messages, deletes the room, and clears both users' cached chat
     * lists.
     *
     * @param  int  $receiver_id  URL param: the other participant
     * @return JsonResponse Success, 404 if no conversation exists, 500 on error
     */
    public function deleteChat($receiver_id): JsonResponse
    {
        try {
            $errorResponse = $this->singleChatConversationService->deleteChat($receiver_id);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status(),
            ], $e->status());
        }

        // A 500-class transaction failure returns the verbatim error envelope.
        if ($errorResponse !== null) {
            return response()->json($errorResponse, 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Conversation deleted successfully',
            'code' => 200,
        ]);
    }

    /**
     * Delete a single chat message.
     *
     * Validates the request, then delegates to
     * {@see SingleChatMessageService::deleteMessage()}. The caller must be the
     * sender or receiver of the message (otherwise 404). Any associated
     * S3 file is removed before the row is soft-deleted, inside a
     * transaction.
     *
     * @param  Request  $request  Body: message_id (the chat row to delete)
     * @return JsonResponse Success, 404 if not found / not permitted,
     *                      422 on validation failure, 500 on error
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
                'code' => 422,
            ], 422);
        }

        try {
            $errorResponse = $this->singleChatMessageService->deleteMessage($request->message_id);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status(),
            ], $e->status());
        }

        // A 500-class transaction failure returns the verbatim error envelope.
        if ($errorResponse !== null) {
            return response()->json($errorResponse, 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Message deleted successfully',
            'code' => 200,
        ]);
    }

    /**
     * Build the unified chat list of 1:1 conversations and groups.
     *
     * Delegates to {@see SingleChatConversationService::listCombined()}, which (when
     * no search keyword is given) caches the result for 30 seconds per
     * user, then paginates the merged list manually.
     *
     * @param  Request  $request  Query: keyword (optional), per_page
     * @return JsonResponse Paginated CombinedChatCollection
     */
    public function listCombined(Request $request): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $keyword = $request->get('keyword');
        $perPage = $request->get('per_page', 20);

        $paginator = $this->singleChatConversationService->listCombined($request, $authUser, $keyword, $perPage);

        return $this->success(
            new CombinedChatCollection($paginator),
            'Chat list retrieved successfully'
        );
    }

    /**
     * Forward an existing message to one or more users.
     *
     * Validates the request, then delegates to
     * {@see SingleChatMessageService::forwardMessage()}, which inside a
     * transaction copies the original message's text/file into a fresh
     * `chats` row for each recipient (self is skipped), stamps
     * `forwarded_from`, and broadcasts each via `MessageSendEvent`.
     *
     * @param  Request  $request  Body: message_id, receiver_ids (array)
     * @return JsonResponse Success with forwarded count, 404 if the
     *                      original is missing, 422 on validation, 500 on error
     */
    public function forwardMessage(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'message_id' => 'required|exists:chats,id',
            'receiver_ids' => 'required|array',
            'receiver_ids.*' => 'exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'code' => 422,
            ], 422);
        }

        try {
            [$outcome, $forwardedCount, $errorResponse] = $this->singleChatMessageService->forwardMessage($request);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status(),
            ], $e->status());
        }

        // A 500-class transaction failure returns the verbatim error envelope.
        if ($outcome === 'error') {
            return response()->json($errorResponse, 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Message forwarded successfully',
            'data' => ['forwarded_count' => $forwardedCount],
            'code' => 200,
        ]);
    }

    /**
     * Broadcast the auth user's typing status to the other participant.
     *
     * Validates the request, then delegates to
     * {@see SingleChatMessageService::typingStatus()} which dispatches
     * the broadcast event.
     *
     * @param  Request  $request  Body: is_typing (boolean)
     * @param  int  $receiver_id  URL param: who should see the indicator
     * @return JsonResponse Success, or 422 on validation failure
     */
    public function typingStatus(Request $request, $receiver_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'is_typing' => 'required|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'code' => 422,
            ], 422);
        }

        $this->singleChatMessageService->typingStatus($request, $receiver_id);

        return response()->json([
            'success' => true,
            'message' => 'Typing status updated',
            'code' => 200,
        ]);
    }
}
