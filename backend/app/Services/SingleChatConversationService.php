<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Http\Controllers\Api\Chat\V2\SingleChatController;
use App\Models\Chat;
use App\Models\Group;
use App\Models\Room;
use App\Models\User;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Business logic for V2 1:1 (direct) chat conversation reading/browsing.
 *
 * Split out of the former {@see SingleChatService} (a
 * 1010-line service that mixed message lifecycle and conversation
 * browsing). This half owns conversation reading/browsing: fetching a
 * paginated conversation, building the combined chat list, resolving
 * rooms, user search, and deleting whole conversations. The message
 * lifecycle half lives in {@see SingleChatMessageService}.
 *
 * Used only by {@see SingleChatController}
 * so the controller only validates input, resolves the authenticated user,
 * applies soft-failure guard clauses, and shapes the JSON response.
 *
 * Expected business-rule failures (bad/self target, missing record) are
 * signalled by throwing {@see ApiException}; the controller maps those onto
 * the error envelope. Unexpected failures bubble up as plain {@see Exception}s
 * and are mapped to a 500 by the controller. All DB reads/writes,
 * transactions, S3 deletions, and cache invalidation are reproduced verbatim
 * from the pre-refactor controller — no behaviour change.
 */
class SingleChatConversationService
{
    /**
     * Get the conversation with a user, paginated newest-first.
     *
     * Bulk-marks the other user's messages as read, finds or creates
     * the room, and returns a page of messages. Each is tagged with
     * `is_my_text` and `should_show_blur` (true only for unviewed media
     * the auth user received — drives the patent blur placeholder).
     * Also reports mutual block status.
     *
     * @param  int  $receiver_id  The other participant.
     * @return array receiver, sender, room, the message paginator, and block flags.
     *
     * @throws ApiException 404 for an invalid / self target.
     */
    public function conversation($receiver_id): array
    {
        $sender_id = Auth::guard('api')->id();

        // Validate receiver exists
        $receiver = User::select('id', 'first_name', 'last_name', 'avatar', 'last_activity_at')
            ->find($receiver_id);

        if (! $receiver || $receiver_id == $sender_id) {
            throw new ApiException('User not found', 404);
        }

        // Mark messages as read in bulk
        Chat::where('receiver_id', $sender_id)
            ->where('sender_id', $receiver_id)
            ->where('status', '!=', 'read')
            ->update(['status' => 'read']);

        // Get or create room
        $room = Room::firstOrCreate([
            'user_one_id' => min($sender_id, $receiver_id),
            'user_two_id' => max($sender_id, $receiver_id),
        ]);

        // Optimized query with proper indexing
        $perPage = request()->get('per_page', 50);
        $page = request()->get('page', 1);

        $chat = Chat::where('room_id', $room->id)
            ->with([
                'sender:id,first_name,last_name,avatar,last_activity_at',
                'receiver:id,first_name,last_name,avatar,last_activity_at',
                'room:id,user_one_id,user_two_id',
                'replyTo:id,sender_id,text,file', // Load reply-to messages
            ])
            ->orderBy('created_at', 'desc')
            ->paginate($perPage);

        // Transform messages
        $chat->getCollection()->transform(function ($message) use ($sender_id) {
            $message->is_my_text = $message->sender_id === $sender_id;
            $message->should_show_blur = false;

            if ($message->receiver_id === $sender_id && $message->is_blurred && ! $message->is_viewed) {
                $message->should_show_blur = true;
            }

            return $message;
        });

        // Check block status
        $blockStatus = $this->checkBlockStatus($sender_id, $receiver_id);

        $sender = User::select('id', 'first_name', 'last_name', 'avatar', 'last_activity_at')
            ->find($sender_id);

        return [
            'receiver' => $receiver,
            'sender' => $sender,
            'room' => $room,
            'chat' => $chat,
            'is_blocked' => $blockStatus['is_blocked'],
            'block_by_me' => $blockStatus['block_by_me'],
        ];
    }

    /**
     * Determine the block relationship between two users.
     *
     * @param  int  $user_id  The auth user (the "me" perspective).
     * @param  int  $other_user_id  The other conversation participant.
     * @return array{is_blocked: bool, block_by_me: bool} Whether a block
     *                                                    exists in either direction, and whether the auth user
     *                                                    is the one who created it.
     */
    private function checkBlockStatus($user_id, $other_user_id): array
    {
        $blockQuery = DB::table('user_blocks')
            ->where(function ($query) use ($user_id, $other_user_id) {
                $query->where('user_id', $user_id)->where('block_user_id', $other_user_id);
            })
            ->orWhere(function ($query) use ($user_id, $other_user_id) {
                $query->where('user_id', $other_user_id)->where('block_user_id', $user_id);
            })
            ->first();

        return [
            'is_blocked' => (bool) $blockQuery,
            'block_by_me' => $blockQuery && $blockQuery->user_id == $user_id,
        ];
    }

    /**
     * Get (or lazily create) the 1:1 room with another user.
     *
     * @param  int  $receiver_id  The other participant.
     * @return Room The room with both users eager-loaded.
     *
     * @throws ApiException 400 for an invalid / self target.
     */
    public function room($receiver_id): Room
    {
        $sender_id = Auth::guard('api')->id();

        if (! User::find($receiver_id) || $receiver_id == $sender_id) {
            throw new ApiException('Invalid user', 400);
        }

        $room = Room::with([
            'userOne:id,first_name,last_name,email,avatar,last_activity_at',
            'userTwo:id,first_name,last_name,email,avatar,last_activity_at',
        ])
            ->firstOrCreate([
                'user_one_id' => min($sender_id, $receiver_id),
                'user_two_id' => max($sender_id, $receiver_id),
            ]);

        return $room;
    }

    /**
     * Search users by name, email, or username (max 50 results).
     *
     * Excludes the auth user from results.
     *
     * @param  string|null  $keyword  The search keyword (required).
     * @return \Illuminate\Database\Eloquent\Collection Matching users.
     *
     * @throws ApiException 400 if no keyword is given.
     */
    public function search($keyword)
    {
        $user_id = Auth::guard('api')->id();

        if (! $keyword) {
            throw new ApiException('Search keyword required', 400);
        }

        $users = User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')
            ->where('id', '!=', $user_id)
            ->where(function ($query) use ($keyword) {
                $query->where('first_name', 'LIKE', "%{$keyword}%")
                    ->orWhere('last_name', 'LIKE', "%{$keyword}%")
                    ->orWhere('email', 'LIKE', "%{$keyword}%")
                    ->orWhere('username', 'LIKE', "%{$keyword}%");
            })
            ->limit(50)
            ->get();

        return $users;
    }

    /**
     * Delete the entire conversation with another user.
     *
     * Inside a transaction: removes every S3-hosted file in the room,
     * soft-deletes all messages, deletes the room, and clears both
     * users' cached chat lists. The transaction-failure branch returns a
     * verbatim 500 envelope (as the original controller did) rather than
     * throwing.
     *
     * @param  int  $receiver_id  The other participant.
     * @return array|null Null on success; a verbatim error-response array
     *                    on a 500-class transaction failure.
     *
     * @throws ApiException 404 if no conversation exists.
     */
    public function deleteChat($receiver_id): ?array
    {
        $sender_id = Auth::guard('api')->id();

        $room = Room::where(function ($query) use ($sender_id, $receiver_id) {
            $query->where('user_one_id', $sender_id)->where('user_two_id', $receiver_id);
        })->orWhere(function ($query) use ($sender_id, $receiver_id) {
            $query->where('user_one_id', $receiver_id)->where('user_two_id', $sender_id);
        })->first();

        if (! $room) {
            throw new ApiException('Conversation not found', 404);
        }

        DB::beginTransaction();
        try {
            // Get all files to delete from S3
            $messages = Chat::where('room_id', $room->id)
                ->whereNotNull('file')
                ->get(['file']);

            // Delete files from S3
            foreach ($messages as $message) {
                if ($message->file && Str::startsWith($message->file, 'https://')) {
                    $filePath = parse_url($message->file, PHP_URL_PATH);
                    Storage::disk('s3')->delete($filePath);
                }
            }

            // Soft delete messages
            Chat::where('room_id', $room->id)->delete();

            // Delete room
            $room->delete();

            DB::commit();

            // Clear cache
            Cache::forget("chat_list_user_{$sender_id}");
            Cache::forget("chat_list_user_{$receiver_id}");

            return null;
        } catch (Exception $e) {
            DB::rollBack();

            return [
                'success' => false,
                'message' => 'Failed to delete conversation',
                'code' => 500,
            ];
        }
    }

    /**
     * Build the unified chat list of 1:1 conversations and groups.
     *
     * When no search keyword is given the result is cached for 30
     * seconds per user (real-time enough, but cheap); a keyword search
     * always bypasses the cache. The merged list is then paginated
     * manually.
     *
     * @param  Request  $request  The incoming request (used for the paginator path/query).
     * @param  User  $authUser  The authenticated user.
     * @param  string|null  $keyword  Optional keyword filter.
     * @param  int  $perPage  Page size.
     * @return LengthAwarePaginator The paginated combined chat list.
     */
    public function listCombined(Request $request, User $authUser, $keyword, $perPage): LengthAwarePaginator
    {
        // Cache key
        $cacheKey = "chat_list_user_{$authUser->id}_keyword_".md5($keyword ?? '');

        // Try to get from cache (cache for 30 seconds for real-time feel)
        if (! $keyword) {
            $combined = Cache::remember($cacheKey, 30, function () use ($authUser, $keyword, $perPage) {
                return $this->getCombinedChatList($authUser, $keyword, $perPage);
            });
        } else {
            $combined = $this->getCombinedChatList($authUser, $keyword, $perPage);
        }

        // Manual pagination
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

    /**
     * Assemble the merged, sorted chat list for a user.
     *
     * Gathers users the auth user has chatted with plus all groups they
     * belong to, attaches each entry's last message, unread count, and
     * metadata, then merges and sorts both sets by last-message time.
     *
     * @param  User  $authUser  The user whose list to build.
     * @param  string|null  $keyword  Optional name/email filter.
     * @param  int  $perPage  Page size (unused here; pagination
     *                        happens in the caller).
     * @return Collection Chat entries sorted newest-first.
     */
    private function getCombinedChatList($authUser, $keyword, $perPage)
    {
        // Optimized query for one-to-one chats
        $usersQuery = User::select('users.id', 'users.first_name', 'users.last_name', 'users.email', 'users.avatar', 'users.last_activity_at')
            ->where('users.id', '!=', $authUser->id)
            ->whereExists(function ($query) use ($authUser) {
                $query->select(DB::raw(1))
                    ->from('chats')
                    ->whereColumn('chats.sender_id', 'users.id')
                    ->where('chats.receiver_id', $authUser->id)
                    ->orWhere(function ($q) use ($authUser) {
                        $q->whereColumn('chats.receiver_id', 'users.id')
                            ->where('chats.sender_id', $authUser->id);
                    });
            });

        if ($keyword) {
            $usersQuery->where(function ($q) use ($keyword) {
                $q->where('first_name', 'LIKE', "%{$keyword}%")
                    ->orWhere('last_name', 'LIKE', "%{$keyword}%")
                    ->orWhere('email', 'LIKE', "%{$keyword}%")
                    ->orWhere('username', 'LIKE', "%{$keyword}%");
            });
        }

        $users = collect($usersQuery->get()->map(function ($user) use ($authUser) {
            // Get last message efficiently
            $lastChat = Chat::where('room_id', function ($query) use ($user, $authUser) {
                $query->select('id')
                    ->from('rooms')
                    ->where(function ($q) use ($user, $authUser) {
                        $q->where('user_one_id', min($authUser->id, $user->id))
                            ->where('user_two_id', max($authUser->id, $user->id));
                    })
                    ->limit(1);
            })
                ->latest()
                ->first(['text', 'file', 'file_type', 'created_at']);

            // Get or create room
            $room = Room::firstOrCreate([
                'user_one_id' => min($authUser->id, $user->id),
                'user_two_id' => max($authUser->id, $user->id),
            ]);

            // Get unread count
            $unreadCount = Chat::where('receiver_id', $authUser->id)
                ->where('sender_id', $user->id)
                ->where('status', '!=', 'read')
                ->count();

            return (object) [
                'type' => 'single',
                'room_id' => $room->id,
                'id' => $user->id,
                'name' => trim("{$user->first_name} {$user->last_name}"),
                'avatar' => $user->avatar ? asset($user->avatar) : asset('default/default_image.jpg'),
                'last_message' => $lastChat?->text,
                'last_message_file' => $lastChat?->file,
                'last_message_time' => $lastChat?->created_at,
                'is_active' => $user->last_activity_at && $user->last_activity_at->gt(now()->subMinutes(5)),
                'member_count' => null,
                'unread_count' => $unreadCount,
            ];
        }));

        // Optimized query for groups
        $groupsQuery = Group::whereHas('members', fn ($q) => $q->where('user_id', $authUser->id));

        if ($keyword) {
            $groupsQuery->where('name', 'LIKE', "%{$keyword}%");
        }

        $groups = collect($groupsQuery->get()->map(function ($group) use ($authUser) {
            $lastMessage = $group->messages()->latest()->first(['text', 'file', 'file_type', 'created_at']);

            // Get unread count for group
            $unreadCount = $group->messages()
                ->where('sender_id', '!=', $authUser->id)
                ->whereDoesntHave('readBy', function ($query) use ($authUser) {
                    $query->where('user_id', $authUser->id);
                })
                ->count();

            return (object) [
                'type' => 'group',
                'room_id' => $group->id,
                'id' => $group->id,
                'name' => $group->name,
                'avatar' => $group->avatar ? asset($group->avatar) : asset('default/default_group.jpg'),
                'last_message' => $lastMessage?->text,
                'last_message_file' => $lastMessage?->file,
                'last_message_time' => $lastMessage?->created_at,
                'is_active' => false,
                'member_count' => $group->members()->count(),
                'unread_count' => $unreadCount,
            ];
        }));

        // Merge and sort by last message time
        return $users->merge($groups)
            ->sortByDesc(fn ($chat) => $chat->last_message_time)
            ->values();
    }
}
