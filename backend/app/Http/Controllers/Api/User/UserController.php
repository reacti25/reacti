<?php

namespace App\Http\Controllers\Api\User;

use Exception;
use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Http\Resources\UserListResource;

/**
 * Read-only access to other users' profiles and the user directory.
 *
 * Backs the authenticated user routes: fetching a single user's public
 * profile and browsing/searching the full user list. The list is
 * decorated with friendship and pending-request flags relative to the
 * auth user.
 */
class UserController extends Controller
{
    use ApiResponse;

    /**
     * Get a single user's public profile by id.
     *
     * @param  int  $id  URL param: the user to fetch
     * @return \Illuminate\Http\JsonResponse  UserResource payload, a
     *                                        "not found" message, or 500 on error
     */
    // get user profile
    public function userDetais($id)
    {
        try {
            $user = User::find($id);

            if (!$user) {
                return $this->error([], 'User not found.', 200);
            }
            return $this->success(new UserResource($user), 'User Profile Retrieved Successfully', 200);
        } catch (Exception $e) {
            return $this->error([], $e->getMessage(), 500);
        }
    }

    /**
     * Browse / search the user directory.
     *
     * Excludes the auth user. Friend ids and pending sent-request ids
     * are preloaded once so each result can be flagged `is_friend` and
     * `is_request_sent` without an N+1 query.
     *
     * @param  Request  $request  Query: search (optional), per_page (default 15)
     * @return \Illuminate\Http\JsonResponse  Paginated UserListResource,
     *                                        401 if unauthenticated, 500 on error
     */
    // user list
    public function userList(Request $request)
    {
        try {
            $currentUser = auth('api')->user();

            if (!$currentUser) {
                return $this->error([], 'Unauthorized', 401);
            }

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

            return $this->success(
                new UserListResource($users),
                'Users retrieved successfully.'
            );
        } catch (Exception $e) {
            return $this->error([], $e->getMessage(), 500);
        }
    }
}
