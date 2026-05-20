<?php

namespace App\Http\Controllers\Api\User;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserListResource;
use App\Http\Resources\UserResource;
use App\Services\UserService;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\Request;

/**
 * Read-only access to other users' profiles and the user directory.
 *
 * Backs the authenticated user routes: fetching a single user's public
 * profile and browsing/searching the full user list. The list is
 * decorated with friendship and pending-request flags relative to the
 * auth user. This is a thin controller — it resolves the auth user,
 * delegates to {@see UserService}, and shapes the JSON response.
 */
class UserController extends Controller
{
    use ApiResponse;

    /**
     * @param  UserService  $userService  User profile/directory business logic.
     */
    public function __construct(private readonly UserService $userService)
    {
        parent::__construct();
    }

    /**
     * Get a single user's public profile by id.
     *
     * Delegates to {@see UserService::userDetais()}.
     *
     * @param  int  $id  URL param: the user to fetch
     * @return \Illuminate\Http\JsonResponse UserResource payload, a
     *                                       "not found" message, or 500 on error
     */
    // get user profile
    public function userDetais($id)
    {
        try {
            $user = $this->userService->userDetais($id);

            if (! $user) {
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
     * Excludes the auth user. Friend ids and pending sent-request ids are
     * preloaded once so each result can be flagged `is_friend` and
     * `is_request_sent` without an N+1 query. Delegates to
     * {@see UserService::userList()}.
     *
     * @param  Request  $request  Query: search (optional), per_page (default 15)
     * @return \Illuminate\Http\JsonResponse Paginated UserListResource,
     *                                       401 if unauthenticated, 500 on error
     */
    // user list
    public function userList(Request $request)
    {
        try {
            $currentUser = auth('api')->user();

            if (! $currentUser) {
                return $this->error([], 'Unauthorized', 401);
            }

            $users = $this->userService->userList($currentUser, $request);

            return $this->success(
                new UserListResource($users),
                'Users retrieved successfully.'
            );
        } catch (Exception $e) {
            return $this->error([], $e->getMessage(), 500);
        }
    }
}
