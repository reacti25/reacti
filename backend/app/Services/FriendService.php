<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Http\Controllers\Api\Friend\FindFriendController;
use App\Http\Controllers\Api\Friend\FriendsController;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Facades\DB;

/**
 * Business logic for contact discovery and established friendships.
 *
 * Extracted from {@see FindFriendController}
 * and {@see FriendsController} so those
 * controllers only validate input and shape responses. Expected
 * business-rule failures are raised as {@see ApiException} with the same
 * status code the controllers previously returned inline.
 */
class FriendService
{
    /**
     * @param  BlockService  $blockService  Block-state queries.
     */
    public function __construct(
        private readonly BlockService $blockService
    ) {}

    /**
     * Match uploaded phone contacts against registered users.
     *
     * Each submitted number is normalized to a `+`-prefixed digits string
     * before matching. Results exclude the caller and anyone they have
     * blocked, and an optional `search` string further filters by
     * name/email/phone. Each match carries an `is_friend` flag.
     *
     * @param  User  $user  The authenticated user.
     * @param  array  $contacts  Validated address-book phone strings.
     * @param  string|null  $search  Optional name/email/phone filter.
     * @return LengthAwarePaginator Paginated
     *                              user matches.
     */
    public function findContacts(User $user, array $contacts, ?string $search)
    {
        // Normalize numbers
        $contacts = collect($contacts)->map(function ($number) {
            // Remove all non-numeric and non-plus characters
            $number = preg_replace('/[^0-9\+]/', '', $number);

            // Fix multiple '+' or malformed numbers
            $number = ltrim($number, '+');
            $number = '+'.$number;

            return $number;
        })->unique()->values();

        // Main query.
        //
        // The blocked-users join is `user_blocks` keyed on `block_user_id`
        // — matching the migration in
        // 2025_10_29_042417_create_user_blocks_table.php and the rest of
        // the codebase. The old `blocked_users` / `blocked_user_id`
        // names never existed and caused this endpoint to throw at the
        // SQL layer.
        $query = User::whereIn('phone', $contacts)
            ->where('id', '!=', $user->id)
            ->whereNotIn('id', function ($q) use ($user) {
                $q->select('block_user_id')
                    ->from('user_blocks')
                    ->where('user_id', $user->id);
            });

        // Optional search filter
        if (! empty($search)) {
            $query->where(function ($q) use ($search) {
                $q->where('username', 'like', "%{$search}%")
                    ->orWhere('first_name', 'like', "%{$search}%")
                    ->orWhere('last_name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        // Select fields + check if already a friend.
        //
        // `is_friend` is a correlated subquery; the auth user's id is passed
        // as a BOUND parameter (selectRaw + bindings) rather than interpolated
        // into the SQL string — no raw user value ever reaches the query text.
        $users = $query->select(
            'id',
            'first_name',
            'last_name',
            'username',
            'email',
            'avatar',
            'phone',
        )->selectRaw(
            'CASE WHEN id IN (SELECT friend_id FROM friends WHERE user_id = ?) THEN true ELSE false END AS is_friend',
            [$user->id]
        )->paginate(15);

        return $users;
    }

    /**
     * List the authenticated user's friends.
     *
     * Friend ids are collected from both directions of the `friends`
     * table and de-duplicated before loading the user records.
     *
     * @param  User  $user  The authenticated user.
     * @return LengthAwarePaginator Paginated
     *                              friend users.
     */
    public function friendList(User $user)
    {
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

        return $friends;
    }

    /**
     * List another user's friends, if the viewer is allowed to.
     *
     * Throws 403 when the profile owner has blocked the auth user. Friend
     * ids are gathered from both directions of the `friends` table.
     *
     * @param  User  $currentUser  The authenticated user (the viewer).
     * @param  int  $userId  Whose friend list to view.
     * @return array{0: User, 1: LengthAwarePaginator}
     *                                                 [profile user, paginated friends].
     *
     * @throws ModelNotFoundException if $userId is unknown.
     * @throws ApiException 403 when the viewer is blocked by the profile owner.
     */
    public function userFriendList(User $currentUser, $userId): array
    {
        // Check if user exists
        $profileUser = User::findOrFail($userId);

        // Check if current user is blocked by profile user.
        //
        // Table is `user_blocks` with `user_id` (blocker) and
        // `block_user_id` (blocked). The legacy `blocked_users` /
        // `blocked_user_id` names were never defined and would error
        // at the SQL layer.
        $isBlocked = $this->blockService->hasBlocked($userId, $currentUser->id);

        if ($isBlocked) {
            throw new ApiException('You cannot view this user\'s friends.', 403);
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

        return [$profileUser, $friends];
    }

    /**
     * Remove the friendship between the auth user and another user.
     *
     * Locates the single `friends` row in whichever direction it was
     * stored and deletes it.
     *
     * @param  User  $user  The authenticated user.
     * @param  int  $friendId  The friend to remove.
     *
     * @throws ApiException 400 when the two users are not actually friends.
     */
    public function unfriend(User $user, $friendId): void
    {
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

        if (! $friendship) {
            throw new ApiException('You are not friends with this user.', 400);
        }

        // Delete the friendship — BOTH rows. Accepting a request creates two
        // reciprocal rows so the friendship is symmetric, and this deleted a
        // single one by id, leaving the pair still friends from the other
        // side: they vanished from one list and stayed in the other, and
        // `alreadyFriends` checks still matched.
        DB::table('friends')
            ->where(function ($query) use ($user, $friendId) {
                $query->where('user_id', $user->id)->where('friend_id', $friendId);
            })
            ->orWhere(function ($query) use ($user, $friendId) {
                $query->where('user_id', $friendId)->where('friend_id', $user->id);
            })
            ->delete();

        // ...and the request that created it. The accepted row used to survive
        // the unfriend, and `sendRequest` treated ANY row as a duplicate, so
        // two people who unfriended could never be friends again: the sender
        // got "Friend request already exists" while the receiver's list — which
        // only shows pending rows — stayed empty. Nothing either of them could
        // do would clear it.
        DB::table('friend_requests')
            ->where(function ($query) use ($user, $friendId) {
                $query->where('sender_id', $user->id)
                    ->where('receiver_id', $friendId);
            })
            ->orWhere(function ($query) use ($user, $friendId) {
                $query->where('sender_id', $friendId)
                    ->where('receiver_id', $user->id);
            })
            ->delete();
    }
}
