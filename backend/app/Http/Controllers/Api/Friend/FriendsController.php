<?php

namespace App\Http\Controllers\Api\Friend;

use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;
use App\Http\Resources\FriendListResource;

/**
 * Reads and manages established friendships for the API.
 *
 * Backs the authenticated friend-list routes: listing the auth user's
 * friends, viewing another user's friend list (subject to block
 * checks), and unfriending. Friendship is stored as paired `friends`
 * rows, so queries here gather ids from both the `user_id` and
 * `friend_id` sides.
 */
class FriendsController extends Controller
{
    use ApiResponse;

    /**
     * List the authenticated user's friends.
     *
     * Friend ids are collected from both directions of the `friends`
     * table and de-duplicated before loading the user records.
     *
     * @return \Illuminate\Http\JsonResponse  Paginated FriendListResource
     */
    // list of all auth user friend
    public function friendList()
    {
        $user = auth('api')->user();

        // friend IDs collect from both side
        $friendIds = DB::table('friends')
            ->where('user_id', $user->id)
            ->pluck('friend_id')
            ->merge(
                DB::table('friends')
                    ->where('friend_id', $user->id)
                    ->pluck('user_id')
            )
            ->unique()
            ->toArray();

        // users fatch with friendsIds
        $friends = User::whereIn('id', $friendIds)
            ->select('id', 'first_name', 'last_name', 'username', 'email', 'phone', 'avatar')
            ->paginate(15);

        return $this->success(
            FriendListResource::collection($friends),
            'Friend list fetched successfully.'
        );
    }

    /**
     * List another user's friends, if the viewer is allowed to.
     *
     * Returns 403 when the profile owner has blocked the auth user.
     * Friend ids are gathered from both directions of the `friends`
     * table.
     *
     * @param  int  $userId  URL param: whose friend list to view
     * @return \Illuminate\Http\JsonResponse  Paginated FriendListResource,
     *                                        or 403 if the viewer is blocked
     * @throws \Illuminate\Database\Eloquent\ModelNotFoundException  if $userId is unknown
     */
    // list of another user's friend list
    public function userFriendList($userId)
    {
        // Check if user exists
        $profileUser = User::findOrFail($userId);

        // Optional: Check if blocked or privacy settings
        $currentUser = auth('api')->user();

        // Check if current user is blocked by profile user.
        //
        // Table is `user_blocks` with `user_id` (blocker) and
        // `block_user_id` (blocked). The legacy `blocked_users` /
        // `blocked_user_id` names were never defined and would error
        // at the SQL layer.
        $isBlocked = DB::table('user_blocks')
            ->where('user_id', $userId)
            ->where('block_user_id', $currentUser->id)
            ->exists();

        if ($isBlocked) {
            // ApiResponse::error signature is ($data, $message, $code).
            // The earlier 2-arg call passed the message as $data and the
            // numeric code as $message, which collapsed every "error"
            // response to HTTP 500.
            return $this->error([], 'You cannot view this user\'s friends.', 403);
        }

        // friend IDs collect from both side
        $friendIds = DB::table('friends')
            ->where('user_id', $userId)
            ->pluck('friend_id')
            ->merge(
                DB::table('friends')
                    ->where('friend_id', $userId)
                    ->pluck('user_id')
            )
            ->unique()
            ->toArray();

        // users fatch with friendsIds
        $friends = User::whereIn('id', $friendIds)
            ->select('id', 'first_name', 'last_name', 'username', 'email', 'phone', 'avatar')
            ->paginate(15);

        return $this->success(
            FriendListResource::collection($friends),
            $profileUser->first_name . '\'s friend list fetched successfully.'
        );
    }

    /**
     * Remove the friendship between the auth user and another user.
     *
     * Locates the single `friends` row in whichever direction it was
     * stored and deletes it.
     *
     * @param  int  $friendId  URL param: the friend to remove
     * @return \Illuminate\Http\JsonResponse  Success, or 400 if the two
     *                                        users are not actually friends
     */
    // user unfriend
    public function unfriend($friendId)
    {
        $user = auth('api')->user();

        // Check if they are friends
        $friendship = DB::table('friends')
            ->where(function ($query) use ($user, $friendId) {
                $query->where('user_id', $user->id)
                    ->where('friend_id', $friendId);
            })
            ->orWhere(function ($query) use ($user, $friendId) {
                $query->where('user_id', $friendId)
                    ->where('friend_id', $user->id);
            })
            ->first();

        if (!$friendship) {
            // ApiResponse::error signature is ($data, $message, $code).
            // Passing the message as $data made the response default to
            // HTTP 500 and put the numeric code in the message field.
            return $this->error([], 'You are not friends with this user.', 400);
        }

        // Delete the friendship
        DB::table('friends')
            ->where('id', $friendship->id)
            ->delete();

        return $this->success(null, 'You have successfully unfriended this user.');
    }
}
