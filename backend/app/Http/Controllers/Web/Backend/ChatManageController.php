<?php

namespace App\Http\Controllers\Web\Backend;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use App\Helper\Helper;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use App\Http\Controllers\Controller;

use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use App\Events\MessageSendEvent;

/**
 * Powers the admin panel's one-to-one (direct) chat area (web guard).
 *
 * Backs the admin direct-chat routes in routes/backend.php: it renders the
 * chat interface and exposes JSON endpoints (consumed by the panel's
 * JavaScript) for listing chat partners, searching users, loading a
 * conversation, sending messages, marking messages seen, and resolving the
 * chat room. The only Blade view rendered is `backend.layouts.chat.index`;
 * every other action returns JSON.
 */
class ChatManageController extends Controller
{
    /**
     * Show the direct-chat page (web interface).
     *
     * @return \Illuminate\View\View  The `backend.layouts.chat.index` Blade view.
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
     * @return JsonResponse  JSON list of chat partners ordered by last activity.
     */
    public function list(): JsonResponse
    {
        $authUser = Auth::user();

        // Fetch users who are connected as senders or receivers with the authenticated user
        $users = User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')
            ->whereHas('senders', function ($query) use ($authUser) {
                $query->where('receiver_id', $authUser->id);
            })
            ->orWhereHas('receivers', function ($query) use ($authUser) {
                $query->where('sender_id', $authUser->id);
            })
            ->where('id', '!=', $authUser->id)
            ->get();

        // Append the last message for each user
        $usersWithMessages = $users->map(function ($user) use ($authUser) {
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

            $user->last_chat = $lastChat;
            return $user;
        });

        // Sort users by the last message's created_at timestamp in descending order
        $sortedUsers = $usersWithMessages->sortByDesc(function ($user) {
            // optional() guards partners that have no messages yet.
            return optional($user->last_chat)->created_at;
        })->values(); // Reset keys after sorting

        $data = [
            'users' => $sortedUsers,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Chat retrieved successfully',
            'data'    => $data,
        ], 200);
    }

    /**
     * Search for users to start a chat with.
     *
     * Matches the keyword against first name, last name, or email,
     * excluding the current user.
     *
     * @param  Request  $request  Query: keyword (search term).
     * @return JsonResponse  JSON list of matching users.
     */
    public function search(Request $request)
    {
        $user_id = Auth::id();

        $keyword = $request->get('keyword');
        $users   = User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')
            ->where('id', '!=', $user_id)
            ->where('first_name', 'LIKE', "%{$keyword}%")->orWhere('last_name', 'LIKE', "%{$keyword}%")->orWhere('email', 'LIKE', "%{$keyword}%")
            ->get();

        $data = [
            'users' => $users,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Chat retrieved successfully',
            'data'    => $data,
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
     * @return JsonResponse  JSON with receiver, sender, room, and the message thread.
     */
    public function conversation($receiver_id): JsonResponse
    {
        $sender_id = Auth::id();

        // Opening the conversation marks the other party's messages as read.
        Chat::where('receiver_id', $sender_id)->where('sender_id', $receiver_id)->update(['status' => 'read']);

        $chat = Chat::query()
            ->where(function ($query) use ($receiver_id, $sender_id) {
                $query->where('sender_id', $sender_id)->where('receiver_id', $receiver_id);
            })
            ->orWhere(function ($query) use ($receiver_id, $sender_id) {
                $query->where('sender_id', $receiver_id)->where('receiver_id', $sender_id);
            })
            ->with([
                'sender:id,first_name,last_name,email,avatar,last_activity_at',
                'receiver:id,first_name,last_name,email,avatar,last_activity_at',
                'room:id,user_one_id,user_two_id',
            ])
            ->orderBy('created_at')
            ->limit(50)
            ->get();

        $room = Room::where(function ($query) use ($receiver_id, $sender_id) {
            $query->where('user_one_id', $receiver_id)->where('user_two_id', $sender_id);
        })->orWhere(function ($query) use ($receiver_id, $sender_id) {
            $query->where('user_two_id', $sender_id)->where('user_one_id', $receiver_id);
        })->first();

        // Lazily create the room on first conversation load if none exists.
        if (! $room) {
            $room = Room::create([
                'user_two_id' => $receiver_id,
            ]);
        }

        $data = [
            'receiver' => User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')->where('id', $receiver_id)->first(),
            'sender'   => User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')->where('id', $sender_id)->first(),
            'room'     => $room,
            'chat'     => $chat,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Messages retrieved successfully',
            'data'    => $data,
            'code'    => 200,
        ]);
    }

    /**
     * Send a message to another user
     *
     * Validates the payload, finds or creates the `Room` between sender and
     * receiver, stores the chat row (with optional file upload), and
     * broadcasts `MessageSendEvent` to the other party.
     *
     * @param  Request  $request      Body: text, file (optional attachment).
     * @param  int|string  $receiver_id  URL param: the user being messaged.
     * @return JsonResponse  The created chat record, or a 422/error payload.
     */
    public function send(Request $request, $receiver_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            // text is optional; attachment is capped at 50 MB.
            'text' => 'nullable|string|max:1000',
            'file'  => 'nullable|file|mimes:jpeg,png,jpg,gif,svg,mp3,wav,mp4,mov,avi,txt,pdf,doc,docx,xls,xlsx,zip,rar|max:51200'
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $sender_id = Auth::id();

        $receiver_exist = User::where('id', $receiver_id)->first();

        // Reject unknown recipients and self-messaging.
        if (!$receiver_exist || $receiver_id == $sender_id) {
            return response()->json(['success' => false, 'message' => 'User not found or cannot chat with your self', 'data' => [],  'code' => 200]);
        }

        //Find Existing Room (or Create New)
        $room = Room::where(function ($query) use ($receiver_id, $sender_id) {
            $query->where('user_one_id', $receiver_id)->where('user_two_id', $sender_id);
        })->orWhere(function ($query) use ($receiver_id, $sender_id) {
            $query->where('user_one_id', $sender_id)->where('user_two_id', $receiver_id);
        })->first();

        // Create the room on the first message between this pair.
        if (!$room) {
            $room = Room::create([
                'user_one_id' => $sender_id,
                'user_two_id' => $receiver_id
            ]);
        }

        // Upload any attachment into the `chat` directory under a unique name.
        $file = null;
        if ($request->hasFile('file')) {
            $file = Helper::fileUpload($request->file('file'),  'chat', time() . '_' . getFileName($request->file('file')));
        }

        $chat = Chat::create([
            'sender_id'   => $sender_id,
            'receiver_id' => $receiver_id,
            'text'        => $request->text,
            'file'        => $file,
            'room_id'     => $room->id,
            'status'      => 'sent'
        ]);

        $chat->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'receiver:id,first_name,last_name,avatar,last_activity_at',
            'room:id,user_one_id,user_two_id'
        ]);

        // broadcast(new MessageSendEvent($chat));
        broadcast(new MessageSendEvent($chat))->toOthers();

        $data = [
            'chat' => $chat
        ];

        return response()->json([
            'success'  => true,
            'message'  => 'Message Sent Successfully.',
            'data'     => $data,
            'code'     => 200
        ]);
    }

    /**
     * Mark every message from a given user as read.
     *
     * @param  int|string  $receiver_id  URL param: the user whose messages are being marked seen.
     * @return JsonResponse  Success payload with the number of rows updated.
     */
    // seen all message
    public function seenAll($receiver_id): JsonResponse
    {
        $sender_id = Auth::id();

        $receiver_exist = User::where('id', $receiver_id)->first();
        // Reject unknown recipients and self-messaging.
        if (! $receiver_exist || $receiver_id == $sender_id) {
            return response()->json(['success' => false, 'message' => 'User not found or cannot chat with yourself', 'data' => [], 'code' => 200]);
        }

        // Flag all messages addressed to this admin from that user as read.
        $chat = Chat::where('receiver_id', $sender_id)->where('sender_id', $receiver_id)->update(['status' => 'read']);

        $data = [
            'chat' => $chat,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Message seen successfully',
            'data'    => $data,
            'code'    => 200,
        ]);
    }

    /**
     * Mark a single message as read.
     *
     * @param  int|string  $chat_id  URL param: the chat row to mark seen.
     * @return JsonResponse  Success payload with the number of rows updated.
     */
    // seen single message
    public function seenSingle($chat_id): JsonResponse
    {
        $sender_id = Auth::id();

        // Scope the update to the current admin as receiver so a user cannot
        // mark someone else's message read.
        $chat = Chat::where('id', $chat_id)->where('receiver_id', $sender_id)->update(['status' => 'read']);

        $data = [
            'chat' => $chat,
        ];

        return response()->json([
            'success' => true,
            'message' => 'Message seen successfully',
            'data'    => $data,
            'code'    => 200,
        ]);
    }

    /**
     * Resolve (or create) the chat room between the current user and another.
     *
     * @param  int|string  $receiver_id  URL param: the other party in the room.
     * @return JsonResponse  JSON containing the room with both participants loaded.
     */
    // room
    public function room($receiver_id)
    {
        // Note: this action resolves the acting user via the `api` guard.
        $sender_id = Auth::guard('api')->id();

        $receiver_exist = User::where('id', $receiver_id)->first();
        // Reject unknown recipients and self-messaging.
        if (! $receiver_exist || $receiver_id == $sender_id) {
            return response()->json(['success' => false, 'message' => 'User not found or cannot chat with yourself', 'data' => [], 'code' => 200]);
        }

        $room = Room::with(['userOne:id,first_name,last_name,email,avatar,last_activity_at', 'userTwo:id,first_name,last_name,email,avatar,last_activity_at'])
            ->where(function ($query) use ($receiver_id, $sender_id) {
                $query->where('user_one_id', $receiver_id)->where('user_two_id', $sender_id);
            })->orWhere(function ($query) use ($receiver_id, $sender_id) {
                $query->where('user_one_id', $sender_id)->where('user_two_id', $receiver_id);
            })->first();

        // Create the room if this pair has never had one.
        if (! $room) {
            $room = Room::create([
                'user_one_id' => $sender_id,
                'user_two_id' => $receiver_id,
            ]);
        }

        $data = [
            'room' => $room,
        ];

        return response()->json(['success' => true, 'message' => 'Group retrieved successfully', 'data' => $data, 'code' => 200]);
    }
}
