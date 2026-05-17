<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Friend;
use App\Models\FriendRequest;
use App\Models\ReportedUser;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Business logic for user-to-user abuse reports.
 *
 * Extracted from {@see \App\Http\Controllers\Api\Friend\ReportUserController}
 * so the controller only validates input and shapes responses. Expected
 * business-rule failures are raised as {@see ApiException} with the same
 * status code the controller previously returned inline. Unexpected
 * failures are re-thrown for the controller's 500 catch block.
 */
class ModerationService
{
    /**
     * File a one-time abuse report against another user.
     *
     * A user may report a given target only once (duplicates raise 409).
     * Inside a transaction the report also deletes any friend requests
     * and the friendship between the two users, so reporting implies
     * severing the relationship. On failure the transaction is rolled
     * back and the exception re-thrown for the controller's 500 handler.
     *
     * @param  User         $user             The authenticated user (reporter).
     * @param  int          $reportedUserId   The user being reported.
     * @param  string|null  $reason           Optional report reason.
     * @param  string|null  $description      Optional report description.
     * @return void
     *
     * @throws ApiException 400 (self-report) or 409 (already reported).
     * @throws \Exception    on any unexpected transaction failure.
     */
    public function reportUser(User $user, $reportedUserId, ?string $reason, ?string $description): void
    {
        if ($user->id == $reportedUserId) {
            throw new ApiException('You cannot report yourself.', 400);
        }

        // Check if already reported
        $existing = ReportedUser::where('user_id', $user->id)
            ->where('reported_user_id', $reportedUserId)
            ->exists();

        if ($existing) {
            throw new ApiException('You have already reported this user.', 409);
        }

        try {
            DB::beginTransaction();

            // Remove friend requests
            FriendRequest::where(function ($q) use ($user, $reportedUserId) {
                $q->where('sender_id', $user->id)->where('receiver_id', $reportedUserId);
            })->orWhere(function ($q) use ($user, $reportedUserId) {
                $q->where('sender_id', $reportedUserId)->where('receiver_id', $user->id);
            })->delete();

            // Remove friendship
            Friend::where(function ($q) use ($user, $reportedUserId) {
                $q->where('user_id', $user->id)->where('friend_id', $reportedUserId);
            })->orWhere(function ($q) use ($user, $reportedUserId) {
                $q->where('user_id', $reportedUserId)->where('friend_id', $user->id);
            })->delete();

            // Create report
            ReportedUser::create([
                'user_id'          => $user->id,
                'reported_user_id' => $reportedUserId,
                'reason'           => $reason,
                'description'      => $description,
            ]);

            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * List the users the authenticated user has reported.
     *
     * @param  User      $user     The authenticated user.
     * @param  int|null  $perPage  Page size (default 10).
     * @return \Illuminate\Contracts\Pagination\LengthAwarePaginator  Paginated
     *                                                                reports.
     */
    public function reportedUsers(User $user, $perPage)
    {
        $reports = ReportedUser::with('reportedUser:id,first_name,last_name,username,avatar')
            ->where('user_id', $user->id)
            ->select(['id', 'reported_user_id', 'reason', 'description', 'created_at'])
            ->paginate($perPage);

        return $reports;
    }
}
