<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Friend;
use App\Models\FriendRequest;
use App\Models\User;
use App\Models\UserBlock;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Business logic for user blocking.
 *
 * Extracted from {@see \App\Http\Controllers\Api\User\UserBlockController} so
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
     * @param  User  $user           The authenticated user.
     * @param  int   $block_user_id  The user to block/unblock.
     * @return string  The success message ("blocked" or "unblocked").
     *
     * @throws ApiException 400 when the user tries to block themselves.
     * @throws \Exception   Re-thrown after rollback on unexpected failure.
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
                'user_id'       => $user->id,
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
     * @param  User     $user     The authenticated user.
     * @param  Request  $request  Query: per_page (default 10).
     * @return \Illuminate\Contracts\Pagination\LengthAwarePaginator  Paginated
     *                                                                blocked users.
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
}
