<?php

namespace App\Http\Controllers\Web\Backend;

use App\Http\Controllers\Controller;
use App\Services\AdminChatService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

/**
 * Powers the admin panel's one-to-one (direct) chat area (web guard).
 *
 * Backs the admin direct-chat routes in routes/backend.php: it renders the
 * chat interface and exposes JSON endpoints (consumed by the panel's
 * JavaScript) for listing chat partners, searching users, loading a
 * conversation, sending messages, marking messages seen, and resolving the
 * chat room. The only Blade view rendered is `backend.layouts.chat.index`;
 * every other action returns JSON.
 *
 * This is a thin controller: it validates input, applies the guard clauses,
 * and shapes the JSON responses. All DB work, the file upload, and the
 * `MessageSendEvent` broadcast live in {@see AdminChatService}.
 */
class ChatManageController extends Controller
{
    /**
     * @param  AdminChatService  $chatService  Direct-chat business logic.
     */
    public function __construct(private readonly AdminChatService $chatService)
    {
        parent::__construct();
    }

    /**
     * Show the direct-chat page (web interface).
     *
     * @return \Illuminate\View\View The `backend.layouts.chat.index` Blade view.
     */
    public function index()
    {

        return view('backend.layouts.chat.index');
    }

    /**
     * Chat user list
     *
     * Returns every user the current admin has exchanged messages with,
     * each annotated with their latest message and sorted most-recent first.
     *
     * @return JsonResponse JSON list of chat partners ordered by last activity.
     */
    public function list(): JsonResponse
    {
        $authUser = Auth::user();

        $sortedUsers = $this->chatService->listChatPartners($authUser);

        $data = [
            'users' => $sortedUsers,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Chat retrieved successfully',
            'data' => $data,
        ], 200);
    }

    /**
     * Search for users to start a chat with.
     *
     * Matches the keyword against first name, last name, or email,
     * excluding the current user.
     *
     * @param  Request  $request  Query: keyword (search term).
     * @return JsonResponse JSON list of matching users.
     */
    public function search(Request $request)
    {
        $user_id = Auth::id();

        $keyword = $request->get('keyword');
        $users = $this->chatService->searchUsers($user_id, $keyword);

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
     ** Get messages between the authenticated user and another user
     *
     * Loads the most recent 50 messages between the current admin and the
     * given user, marks incoming messages read as a side effect, and
     * ensures a `Room` exists for the pair.
     *
     * @param  int|string  $receiver_id  URL param: the other party in the conversation.
     * @return JsonResponse JSON with receiver, sender, room, and the message thread.
     */
    public function conversation($receiver_id): JsonResponse
    {
        $sender_id = Auth::id();

        $data = $this->chatService->conversation($sender_id, $receiver_id);

        return response()->json([
            'success' => true,
            'message' => 'Messages retrieved successfully',
            'data' => $data,
            'code' => 200,
        ]);
    }

    /**
     * Send a message to another user
     *
     * Validates the payload, finds or creates the `Room` between sender and
     * receiver, stores the chat row (with optional file upload), and
     * broadcasts `MessageSendEvent` to the other party.
     *
     * @param  Request  $request  Body: text, file (optional attachment).
     * @param  int|string  $receiver_id  URL param: the user being messaged.
     * @return JsonResponse The created chat record, or a 422/error payload.
     */
    public function send(Request $request, $receiver_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            // text is optional; attachment is capped at 50 MB.
            'text' => 'nullable|string|max:1000',
            'file' => 'nullable|file|mimes:jpeg,png,jpg,gif,svg,mp3,wav,mp4,mov,avi,txt,pdf,doc,docx,xls,xlsx,zip,rar|max:51200',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $sender_id = Auth::id();

        $receiver_exist = $this->chatService->findReceiver($receiver_id);

        // Reject unknown recipients and self-messaging.
        if (! $receiver_exist || $receiver_id == $sender_id) {
            return response()->json(['success' => false, 'message' => 'User not found or cannot chat with your self', 'data' => [],  'code' => 200]);
        }

        $chat = $this->chatService->sendMessage($request, $sender_id, $receiver_id);

        $data = [
            'chat' => $chat,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Message Sent Successfully.',
            'data' => $data,
            'code' => 200,
        ]);
    }

    /**
     * Mark every message from a given user as read.
     *
     * @param  int|string  $receiver_id  URL param: the user whose messages are being marked seen.
     * @return JsonResponse Success payload with the number of rows updated.
     */
    // seen all message
    public function seenAll($receiver_id): JsonResponse
    {
        $sender_id = Auth::id();

        $receiver_exist = $this->chatService->findReceiver($receiver_id);
        // Reject unknown recipients and self-messaging.
        if (! $receiver_exist || $receiver_id == $sender_id) {
            return response()->json(['success' => false, 'message' => 'User not found or cannot chat with yourself', 'data' => [], 'code' => 200]);
        }

        // Flag all messages addressed to this admin from that user as read.
        $chat = $this->chatService->seenAll($sender_id, $receiver_id);

        $data = [
            'chat' => $chat,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Message seen successfully',
            'data' => $data,
            'code' => 200,
        ]);
    }

    /**
     * Mark a single message as read.
     *
     * @param  int|string  $chat_id  URL param: the chat row to mark seen.
     * @return JsonResponse Success payload with the number of rows updated.
     */
    // seen single message
    public function seenSingle($chat_id): JsonResponse
    {
        $sender_id = Auth::id();

        // Scope the update to the current admin as receiver so a user cannot
        // mark someone else's message read.
        $chat = $this->chatService->seenSingle($sender_id, $chat_id);

        $data = [
            'chat' => $chat,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Message seen successfully',
            'data' => $data,
            'code' => 200,
        ]);
    }

    /**
     * Resolve (or create) the chat room between the current user and another.
     *
     * @param  int|string  $receiver_id  URL param: the other party in the room.
     * @return JsonResponse JSON containing the room with both participants loaded.
     */
    // room
    public function room($receiver_id)
    {
        // Note: this action resolves the acting user via the `api` guard.
        $sender_id = Auth::guard('api')->id();

        $receiver_exist = $this->chatService->findReceiver($receiver_id);
        // Reject unknown recipients and self-messaging.
        if (! $receiver_exist || $receiver_id == $sender_id) {
            return response()->json(['success' => false, 'message' => 'User not found or cannot chat with yourself', 'data' => [], 'code' => 200]);
        }

        $room = $this->chatService->resolveRoom($sender_id, $receiver_id);

        $data = [
            'room' => $room,
        ];

        return response()->json(['success' => true, 'message' => 'Group retrieved successfully', 'data' => $data, 'code' => 200]);
    }
}
