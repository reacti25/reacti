<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Http\Controllers\Api\Friend\FriendRequestController;
use App\Models\Friend;
use App\Models\FriendRequest;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Business logic for the friend-request lifecycle.
 *
 * Extracted from {@see FriendRequestController}
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
    /**
     * Most friend requests one account may send per hour / per day.
     *
     * Generous for a person and useless for a script — the point is not to
     * inconvenience anyone real, it is that limiting *discovery* alone never
     * bounds the harm. Someone who finds a way to enumerate accounts still has
     * to send the requests one at a time, and this is where that stops.
     */
    public const MAX_REQUESTS_PER_HOUR = 20;

    /** @see self::MAX_REQUESTS_PER_HOUR */
    public const MAX_REQUESTS_PER_DAY = 100;

    /**
     * Requests declined in a day before the daily cap is cut to this.
     *
     * Whoever is being turned down repeatedly is precisely the account worth
     * slowing, and it needs no report and no moderator: the people receiving
     * the requests have already said what they think.
     */
    public const REJECTED_BACKOFF_THRESHOLD = 5;

    /** @see self::REJECTED_BACKOFF_THRESHOLD */
    public const BACKED_OFF_DAILY_LIMIT = 10;

    /**
     * Throws when [$sender] has already sent too many requests.
     *
     * Counts rows rather than a cache key on purpose: a cache flush or a
     * restart must not hand someone a fresh allowance, and the table is the
     * only record that survives both.
     *
     * @param  User  $sender  The authenticated sender.
     *
     * @throws ApiException 429 when an hourly or daily cap is reached.
     */
    private function assertWithinRequestLimits(User $sender): void
    {
        $sentInLastHour = FriendRequest::where('sender_id', $sender->id)
            ->where('created_at', '>=', now()->subHour())
            ->count();

        if ($sentInLastHour >= self::MAX_REQUESTS_PER_HOUR) {
            throw new ApiException(
                'You have sent a lot of friend requests recently. Please try again later.',
                429,
            );
        }

        $sentToday = FriendRequest::where('sender_id', $sender->id)
            ->where('created_at', '>=', now()->subDay())
            ->count();

        // 'declined' is the value the enum actually uses — 'rejected' would
        // have matched nothing and the back-off would have been dead code.
        $rejectedToday = FriendRequest::where('sender_id', $sender->id)
            ->where('status', 'declined')
            ->where('updated_at', '>=', now()->subDay())
            ->count();

        $dailyLimit = $rejectedToday >= self::REJECTED_BACKOFF_THRESHOLD
            ? self::BACKED_OFF_DAILY_LIMIT
            : self::MAX_REQUESTS_PER_DAY;

        if ($sentToday >= $dailyLimit) {
            throw new ApiException(
                'You have sent a lot of friend requests recently. Please try again later.',
                429,
            );
        }
    }

    public function sendRequest(User $sender, $receiverId): void
    {
        if ($sender->id == $receiverId) {
            throw new ApiException('You cannot send a friend request to yourself.', 400);
        }

        $this->assertWithinRequestLimits($sender);

        // Only a request that is still PENDING may block a new one.
        //
        // This used to match any row in either direction whatever its status,
        // and rows are never removed: accepting sets 'accepted', declining sets
        // 'declined'. So a declined request blocked that person from ever asking
        // again, and — because unfriending deleted the friendship but left the
        // accepted row behind — two people who unfriended could NEVER be
        // friends again. The sender got "Friend request already exists" while
        // the receiver's list, which only shows pending rows, stayed empty:
        // a permanent dead end with nothing visible to clear.
        $pending = FriendRequest::where('status', 'pending')
            ->where(function ($q) use ($sender, $receiverId) {
                $q->where(function ($inner) use ($sender, $receiverId) {
                    $inner->where('sender_id', $sender->id)
                        ->where('receiver_id', $receiverId);
                })->orWhere(function ($inner) use ($sender, $receiverId) {
                    $inner->where('sender_id', $receiverId)
                        ->where('receiver_id', $sender->id);
                });
            })
            ->first();

        if ($pending) {
            throw new ApiException('Friend request already exists.', 409);
        }

        // Already friends is a different situation and deserves its own words —
        // "request already exists" sent someone hunting for a request that was
        // not there.
        $alreadyFriends = DB::table('friends')
            ->where(function ($q) use ($sender, $receiverId) {
                $q->where('user_id', $sender->id)->where('friend_id', $receiverId);
            })
            ->orWhere(function ($q) use ($sender, $receiverId) {
                $q->where('user_id', $receiverId)->where('friend_id', $sender->id);
            })
            ->exists();

        if ($alreadyFriends) {
            throw new ApiException('You are already friends with this user.', 409);
        }

        // Clear the settled rows from any earlier round so the new request is
        // the only one between these two. Without this, a second decline would
        // leave two 'declined' rows and the history would grow forever.
        FriendRequest::whereIn('status', ['declined', 'accepted'])
            ->where(function ($q) use ($sender, $receiverId) {
                $q->where(function ($inner) use ($sender, $receiverId) {
                    $inner->where('sender_id', $sender->id)
                        ->where('receiver_id', $receiverId);
                })->orWhere(function ($inner) use ($sender, $receiverId) {
                    $inner->where('sender_id', $receiverId)
                        ->where('receiver_id', $sender->id);
                });
            })
            ->delete();

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
     * @return LengthAwarePaginator Paginated
     *                              requests.
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
     * @return LengthAwarePaginator Paginated
     *                              requests.
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
