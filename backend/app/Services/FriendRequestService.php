<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Friend;
use App\Models\FriendRequest;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Business logic for the friend-request lifecycle.
 *
 * Extracted from {@see \App\Http\Controllers\Api\Friend\FriendRequestController}
 * so the controller only validates input and shapes responses. Expected
 * business-rule failures are raised as {@see ApiException} with the same
 * status code the controller previously returned inline. Unexpected
 * failures (e.g. transaction errors) are re-thrown for the controller's
 * 500 catch block.
 */
class FriendRequestService
{
    /**
     * Send a friend request to another user.
     *
     * Rejects self-requests and refuses to create a duplicate when a
     * request already exists in either direction. The insert runs inside
     * a transaction; on failure the transaction is rolled back and the
     * exception re-thrown for the controller's 500 handler.
     *
     * @param  User  $sender  The authenticated user sending the request.
     * @param  int  $receiverId  The user to receive the request.
     *
     * @throws ApiException 400 (self-request) or 409 (request already exists).
     * @throws \Exception on any unexpected transaction failure.
     */
    public function sendRequest(User $sender, $receiverId): void
    {
        if ($sender->id == $receiverId) {
            throw new ApiException('You cannot send a friend request to yourself.', 400);
        }

        // Check existing request
        $existing = FriendRequest::where(function ($q) use ($sender, $receiverId) {
            $q->where('sender_id', $sender->id)
                ->where('receiver_id', $receiverId);
        })->orWhere(function ($q) use ($sender, $receiverId) {
            $q->where('sender_id', $receiverId)
                ->where('receiver_id', $sender->id);
        })->first();

        if ($existing) {
            throw new ApiException('Friend request already exists.', 409);
        }

        try {
            DB::beginTransaction();

            FriendRequest::create([
                'sender_id' => $sender->id,
                'receiver_id' => $receiverId,
                'status' => 'pending',
            ]);

            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Cancel a pending friend request the auth user has sent.
     *
     * @param  User  $user  The authenticated user.
     * @param  int  $receiverId  The request's recipient.
     *
     * @throws ApiException 404 when there is no pending request to cancel.
     * @throws \Exception on any unexpected delete failure.
     */
    public function cancelRequest(User $user, $receiverId): void
    {
        $requestData = FriendRequest::where('sender_id', $user->id)
            ->where('receiver_id', $receiverId)
            ->where('status', 'pending')
            ->first();

        if (! $requestData) {
            throw new ApiException('No pending friend request found to cancel.', 404);
        }

        $requestData->delete();
    }

    /**
     * Accept a pending friend request addressed to the auth user.
     *
     * Inside a transaction: marks the request `accepted` and creates the
     * two reciprocal `Friend` rows so the friendship is symmetric. On
     * failure the transaction is rolled back and the exception re-thrown
     * for the controller's 500 handler.
     *
     * @param  User  $receiver  The authenticated user accepting the request.
     * @param  int  $senderId  The user who sent the request.
     *
     * @throws ApiException 404 when there is no pending request.
     * @throws \Exception on any unexpected transaction failure.
     */
    public function acceptRequest(User $receiver, $senderId): void
    {
        $friendRequest = FriendRequest::where('sender_id', $senderId)
            ->where('receiver_id', $receiver->id)
            ->where('status', 'pending')
            ->first();

        if (! $friendRequest) {
            throw new ApiException('Friend request not found.', 404);
        }

        try {
            DB::beginTransaction();

            // Update request status
            $friendRequest->update([
                'status' => 'accepted',
                'accepted_at' => Carbon::now(),
            ]);

            // Create friendship (both sides)
            Friend::create([
                'user_id' => $receiver->id,
                'friend_id' => $senderId,
                'became_friends_at' => Carbon::now(),
            ]);

            Friend::create([
                'user_id' => $senderId,
                'friend_id' => $receiver->id,
                'became_friends_at' => Carbon::now(),
            ]);

            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Decline a pending friend request addressed to the auth user.
     *
     * Marks the request `declined` (it is kept, not deleted) and stamps
     * `declined_at`.
     *
     * @param  User  $receiver  The authenticated user declining the request.
     * @param  int  $senderId  The user who sent the request.
     *
     * @throws ApiException 404 when there is no pending request.
     * @throws \Exception on any unexpected update failure.
     */
    public function declineRequest(User $receiver, $senderId): void
    {
        $friendRequest = FriendRequest::where('sender_id', $senderId)
            ->where('receiver_id', $receiver->id)
            ->where('status', 'pending')
            ->first();

        if (! $friendRequest) {
            throw new ApiException('Friend request not found.', 404);
        }

        $friendRequest->update([
            'status' => 'declined',
            'declined_at' => Carbon::now(),
        ]);
    }

    /**
     * List the auth user's incoming pending friend requests.
     *
     * @param  User  $user  The authenticated user.
     * @param  int|null  $perPage  Page size (default 10).
     * @return \Illuminate\Contracts\Pagination\LengthAwarePaginator Paginated
     *                                                               requests.
     */
    public function getRequests(User $user, $perPage)
    {
        $requests = FriendRequest::with('sender:id,first_name,last_name,username,avatar')
            ->where('receiver_id', $user->id)
            ->where('status', 'pending')
            ->paginate($perPage);

        return $requests;
    }

    /**
     * List the pending friend requests the auth user has sent.
     *
     * @param  User  $user  The authenticated user.
     * @param  int|null  $perPage  Page size (default 10).
     * @return \Illuminate\Contracts\Pagination\LengthAwarePaginator Paginated
     *                                                               requests.
     */
    public function getSentRequests(User $user, $perPage)
    {
        $sentRequests = FriendRequest::with('receiver:id,first_name,last_name,username,avatar')
            ->where('sender_id', $user->id)
            ->where('status', 'pending')
            ->paginate($perPage);

        return $sentRequests;
    }
}
