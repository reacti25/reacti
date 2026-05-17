<?php

namespace App\Services;

use App\Events\MessageSendEvent;
use App\Helper\Helper;
use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;

/**
 * Business logic for the admin panel's one-to-one (direct) chat area.
 *
 * Extracted from {@see \App\Http\Controllers\Web\Backend\ChatManageController}
 * so the controller only validates input and shapes the JSON responses. The
 * service returns plain data (models, collections, arrays); the controller
 * builds the `response()->json()` envelopes. All DB reads/writes, the
 * file upload, and the `MessageSendEvent` broadcast are reproduced verbatim
 * from the pre-refactor controller — no behaviour change.
 */
class AdminChatService
{
    /**
     * List every user the given admin has exchanged messages with.
     *
     * Each partner is annotated with their latest message and the result
     * is sorted most-recent first. Partners with no messages sort last via
     * {@see optional()}.
     *
     * @param  User  $authUser  The authenticated admin.
     * @return Collection  Chat partners ordered by last activity, keys reset.
     */
    public function listChatPartners(User $authUser): Collection
    {
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

        return $sortedUsers;
    }

    /**
     * Search for users to start a chat with.
     *
     * Matches the keyword against first name, last name, or email,
     * excluding the current user.
     *
     * @param  int|string|null  $userId   The current user's id (excluded from results).
     * @param  string|null      $keyword  The search term.
     * @return Collection  Matching users.
     */
    public function searchUsers($userId, $keyword): Collection
    {
        $users = User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')
            ->where('id', '!=', $userId)
            ->where('first_name', 'LIKE', "%{$keyword}%")->orWhere('last_name', 'LIKE', "%{$keyword}%")->orWhere('email', 'LIKE', "%{$keyword}%")
            ->get();

        return $users;
    }

    /**
     * Load the conversation between the admin and another user.
     *
     * Opening the conversation marks the other party's messages as read as
     * a side effect, loads the most recent 50 messages, and lazily creates
     * the `Room` for the pair on first load if none exists.
     *
     * @param  int|string  $senderId    The acting admin's id.
     * @param  int|string  $receiverId  The other party in the conversation.
     * @return array  ['receiver', 'sender', 'room', 'chat'] for the JSON payload.
     */
    public function conversation($senderId, $receiverId): array
    {
        // Opening the conversation marks the other party's messages as read.
        Chat::where('receiver_id', $senderId)->where('sender_id', $receiverId)->update(['status' => 'read']);

        $chat = Chat::query()
            ->where(function ($query) use ($receiverId, $senderId) {
                $query->where('sender_id', $senderId)->where('receiver_id', $receiverId);
            })
            ->orWhere(function ($query) use ($receiverId, $senderId) {
                $query->where('sender_id', $receiverId)->where('receiver_id', $senderId);
            })
            ->with([
                'sender:id,first_name,last_name,email,avatar,last_activity_at',
                'receiver:id,first_name,last_name,email,avatar,last_activity_at',
                'room:id,user_one_id,user_two_id',
            ])
            ->orderBy('created_at')
            ->limit(50)
            ->get();

        $room = Room::where(function ($query) use ($receiverId, $senderId) {
            $query->where('user_one_id', $receiverId)->where('user_two_id', $senderId);
        })->orWhere(function ($query) use ($receiverId, $senderId) {
            $query->where('user_two_id', $senderId)->where('user_one_id', $receiverId);
        })->first();

        // Lazily create the room on first conversation load if none exists.
        if (! $room) {
            $room = Room::create([
                'user_two_id' => $receiverId,
            ]);
        }

        $data = [
            'receiver' => User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')->where('id', $receiverId)->first(),
            'sender'   => User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')->where('id', $senderId)->first(),
            'room'     => $room,
            'chat'     => $chat,
        ];

        return $data;
    }

    /**
     * Find an existing user by id.
     *
     * Used by the controller's guard clauses to reject unknown recipients.
     *
     * @param  int|string  $receiverId  The id to look up.
     * @return User|null  The matching user, or null when none exists.
     */
    public function findReceiver($receiverId): ?User
    {
        return User::where('id', $receiverId)->first();
    }

    /**
     * Send a direct message from the admin to another user.
     *
     * Finds or creates the `Room` between the pair, stores the chat row
     * (with optional file upload), eager-loads the relations, and broadcasts
     * `MessageSendEvent` to the other party. The caller is responsible for
     * confirming the receiver exists and is not the sender before calling.
     *
     * @param  Request      $request     The incoming request (text, file).
     * @param  int|string   $senderId    The acting admin's id.
     * @param  int|string   $receiverId  The user being messaged.
     * @return Chat  The created chat record with relations loaded.
     */
    public function sendMessage(Request $request, $senderId, $receiverId): Chat
    {
        //Find Existing Room (or Create New)
        $room = Room::where(function ($query) use ($receiverId, $senderId) {
            $query->where('user_one_id', $receiverId)->where('user_two_id', $senderId);
        })->orWhere(function ($query) use ($receiverId, $senderId) {
            $query->where('user_one_id', $senderId)->where('user_two_id', $receiverId);
        })->first();

        // Create the room on the first message between this pair.
        if (!$room) {
            $room = Room::create([
                'user_one_id' => $senderId,
                'user_two_id' => $receiverId
            ]);
        }

        // Upload any attachment into the `chat` directory under a unique name.
        $file = null;
        if ($request->hasFile('file')) {
            $file = Helper::fileUpload($request->file('file'),  'chat', time() . '_' . getFileName($request->file('file')));
        }

        $chat = Chat::create([
            'sender_id'   => $senderId,
            'receiver_id' => $receiverId,
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

        return $chat;
    }

    /**
     * Mark every message from a given user to the admin as read.
     *
     * @param  int|string  $senderId    The acting admin's id (the receiver of the messages).
     * @param  int|string  $receiverId  The user whose messages are being marked seen.
     * @return int  The number of rows updated.
     */
    public function seenAll($senderId, $receiverId): int
    {
        // Flag all messages addressed to this admin from that user as read.
        return Chat::where('receiver_id', $senderId)->where('sender_id', $receiverId)->update(['status' => 'read']);
    }

    /**
     * Mark a single message addressed to the admin as read.
     *
     * Scoped to the current admin as receiver so a user cannot mark
     * someone else's message read.
     *
     * @param  int|string  $senderId  The acting admin's id (the receiver of the message).
     * @param  int|string  $chatId    The chat row to mark seen.
     * @return int  The number of rows updated.
     */
    public function seenSingle($senderId, $chatId): int
    {
        // Scope the update to the current admin as receiver so a user cannot
        // mark someone else's message read.
        return Chat::where('id', $chatId)->where('receiver_id', $senderId)->update(['status' => 'read']);
    }

    /**
     * Resolve (or create) the chat room between the admin and another user.
     *
     * The caller is responsible for confirming the receiver exists and is
     * not the sender before calling.
     *
     * @param  int|string  $senderId    The acting user's id.
     * @param  int|string  $receiverId  The other party in the room.
     * @return Room  The resolved or freshly created room.
     */
    public function resolveRoom($senderId, $receiverId): Room
    {
        $room = Room::with(['userOne:id,first_name,last_name,email,avatar,last_activity_at', 'userTwo:id,first_name,last_name,email,avatar,last_activity_at'])
            ->where(function ($query) use ($receiverId, $senderId) {
                $query->where('user_one_id', $receiverId)->where('user_two_id', $senderId);
            })->orWhere(function ($query) use ($receiverId, $senderId) {
                $query->where('user_one_id', $senderId)->where('user_two_id', $receiverId);
            })->first();

        // Create the room if this pair has never had one.
        if (! $room) {
            $room = Room::create([
                'user_one_id' => $senderId,
                'user_two_id' => $receiverId,
            ]);
        }

        return $room;
    }
}
