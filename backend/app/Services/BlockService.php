<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Http\Controllers\Api\User\UserBlockController;
use App\Models\Friend;
use App\Models\FriendRequest;
use App\Models\User;
use App\Models\UserBlock;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Business logic for user blocking.
 *
 * Extracted from {@see UserBlockController} so
 * the controller only validates input and shapes responses. Expected
 * business-rule failures are raised as {@see ApiException} with the same
 * status code the controller previously returned inline.
 */
class BlockService
{
    /**
     * Toggle the block state between the auth user and another user.
     *
     * If a block already exists it is removed (unblock) and the
     * transaction is committed inside the try. Otherwise, inside the same
     * transaction, the block is created and any friend requests and the
     * friendship between the two users are deleted — blocking implies
     * severing the relationship. Self-blocking is rejected.
     *
     * On any failure the transaction is rolled back and the exception is
     * re-thrown so the controller's 500 catch maps it verbatim.
     *
     * @param  User  $user  The authenticated user.
     * @param  int  $block_user_id  The user to block/unblock.
     * @return string The success message ("blocked" or "unblocked").
     *
     * @throws ApiException 400 when the user tries to block themselves.
     * @throws \Exception Re-thrown after rollback on unexpected failure.
     */
    public function toggleBlock(User $user, $block_user_id): string
    {
        if ($user->id == $block_user_id) {
            throw new ApiException('You cannot block yourself.', 400);
        }

        // Check if already blocked
        $existing = UserBlock::where('user_id', $user->id)
            ->where('block_user_id', $block_user_id)
            ->first();

        try {
            DB::beginTransaction();

            if ($existing) {
                // UNBLOCK
                $existing->delete();
                DB::commit();

                return 'User has been unblocked.';
            }

            // BLOCK
            // Remove friend requests
            FriendRequest::where(function ($q) use ($user, $block_user_id) {
                $q->where('sender_id', $user->id)->where('receiver_id', $block_user_id);
            })->orWhere(function ($q) use ($user, $block_user_id) {
                $q->where('sender_id', $block_user_id)->where('receiver_id', $user->id);
            })->delete();

            // Remove friendship
            Friend::where(function ($q) use ($user, $block_user_id) {
                $q->where('user_id', $user->id)->where('friend_id', $block_user_id);
            })->orWhere(function ($q) use ($user, $block_user_id) {
                $q->where('user_id', $block_user_id)->where('friend_id', $user->id);
            })->delete();

            // Create block
            UserBlock::create([
                'user_id' => $user->id,
                'block_user_id' => $block_user_id,
            ]);

            DB::commit();

            return 'User has been blocked.';
        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * List the users the authenticated user has blocked.
     *
     * @param  User  $user  The authenticated user.
     * @param  Request  $request  Query: per_page (default 10).
     * @return LengthAwarePaginator Paginated
     *                              blocked users.
     */
    public function blockedUsers(User $user, Request $request)
    {
        $perPage = $request->get('per_page', 10); // ?per_page=15

        $blockedUsers = UserBlock::with('blockedUser:id,first_name,last_name,username,avatar')
            ->where('user_id', $user->id)
            ->select(['id', 'block_user_id', 'created_at'])
            ->paginate($perPage);

        return $blockedUsers;
    }

    /**
     * Whether a block exists between two users in EITHER direction.
     *
     * The single authority for the "are these two users blocked from
     * each other" check the chat services run before allowing a
     * conversation — previously copy-pasted across ChatService and
     * SingleChatService.
     *
     * @param  int  $userA  One user id.
     * @param  int  $userB  The other user id.
     * @return bool True if either user has blocked the other.
     */
    public function blockExistsBetween(int $userA, int $userB): bool
    {
        return DB::table('user_blocks')
            ->where(function ($query) use ($userA, $userB) {
                $query->where('user_id', $userA)->where('block_user_id', $userB);
            })
            ->orWhere(function ($query) use ($userA, $userB) {
                $query->where('user_id', $userB)->where('block_user_id', $userA);
            })
            ->exists();
    }

    /**
     * Whether one specific user has blocked another (one direction only).
     *
     * @param  int  $blocker  The user who may have created the block.
     * @param  int  $blocked  The user who may have been blocked.
     * @return bool True if $blocker has blocked $blocked.
     */
    public function hasBlocked(int $blocker, int $blocked): bool
    {
        return DB::table('user_blocks')
            ->where('user_id', $blocker)
            ->where('block_user_id', $blocked)
            ->exists();
    }
}
