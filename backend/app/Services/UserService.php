<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Business logic for reading user profiles and the user directory.
 *
 * Extracted from {@see \App\Http\Controllers\Api\User\UserController} so the
 * controller only validates input and shapes responses. These methods have
 * no expected business-rule failures of their own — the "User not found"
 * case in {@see self::userDetais()} is returned to the controller as a null
 * lookup so the controller can reproduce its pre-existing HTTP-200 envelope.
 */
class UserService
{
    /**
     * Look up a single user's public profile by id.
     *
     * Returns `null` when the user does not exist; the controller maps
     * that to its (quirky) HTTP-200 "User not found." response.
     *
     * @param  int  $id  The user id to fetch.
     * @return User|null  The user, or null when no row matches.
     */
    public function userDetais($id): ?User
    {
        return User::find($id);
    }

    /**
     * Browse / search the user directory for the authenticated user.
     *
     * Excludes the auth user. Friend ids and pending sent-request ids are
     * preloaded once so each result can be flagged `is_friend` and
     * `is_request_sent` without an N+1 query.
     *
     * @param  User     $currentUser  The authenticated user.
     * @param  Request  $request      Query: search (optional), per_page (default 15).
     * @return \Illuminate\Contracts\Pagination\LengthAwarePaginator  Paginated
     *                                                                user matches.
     */
    public function userList(User $currentUser, Request $request)
    {
        // Preload friend IDs to avoid N+1
        $sent = DB::table('friends')
            ->where('user_id', $currentUser->id)
            ->select('friend_id as user_id');

        $received = DB::table('friends')
            ->where('friend_id', $currentUser->id)
            ->select('user_id');

        $friendIds = $sent->union($received)->pluck('user_id');

        // Preload sent friend request IDs
        $sentRequests = DB::table('friend_requests')
            ->where('sender_id', $currentUser->id)
            ->where('status', 'pending')
            ->pluck('receiver_id');

        $perPage = $request->get('per_page', 15);
        $search = $request->get('search');

        $query = User::query()
            ->when($search, function ($q) use ($search) {
                $q->where(function ($sq) use ($search) {
                    $sq->where('first_name', 'like', "%{$search}%")
                        ->orWhere('last_name', 'like', "%{$search}%")
                        ->orWhere('username', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%")
                        ->orWhereRaw("CONCAT(first_name, ' ', last_name) LIKE ?", ["%{$search}%"]);
                });
            })
            ->where('id', '!=', $currentUser->id)
            ->select(['id', 'first_name', 'last_name', 'username', 'avatar']);

        $users = $query->paginate($perPage);

        // Add flags: is_friend & is_request_sent
        $users->getCollection()->transform(function ($user) use ($friendIds, $sentRequests) {
            $user->is_friend = $friendIds->contains($user->id);
            $user->is_request_sent = $sentRequests->contains($user->id);
            return $user;
        });

        return $users;
    }
}
