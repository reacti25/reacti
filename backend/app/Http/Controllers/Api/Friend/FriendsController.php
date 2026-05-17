<?php

namespace App\Http\Controllers\Api\Friend;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\FriendListResource;
use App\Services\FriendService;
use App\Traits\ApiResponse;

/**
 * Reads and manages established friendships for the API.
 *
 * Backs the authenticated friend-list routes: listing the auth user's
 * friends, viewing another user's friend list (subject to block
 * checks), and unfriending. This is a thin controller — it validates
 * input and delegates to {@see FriendService}.
 */
class FriendsController extends Controller
{
    use ApiResponse;

    /**
     * @param  FriendService  $friendService  Friend/friendship business logic.
     */
    public function __construct(private readonly FriendService $friendService)
    {
        parent::__construct();
    }

    /**
     * List the authenticated user's friends.
     *
     * Delegates to {@see FriendService::friendList()}.
     *
     * @return \Illuminate\Http\JsonResponse  Paginated FriendListResource
     */
    // list of all auth user friend
    public function friendList()
    {
        $user = auth('api')->user();

        $friends = $this->friendService->friendList($user);

        return $this->success(
            FriendListResource::collection($friends),
            'Friend list fetched successfully.'
        );
    }

    /**
     * List another user's friends, if the viewer is allowed to.
     *
     * Returns 403 when the profile owner has blocked the auth user.
     * Delegates to {@see FriendService::userFriendList()}.
     *
     * @param  int  $userId  URL param: whose friend list to view
     * @return \Illuminate\Http\JsonResponse  Paginated FriendListResource,
     *                                        or 403 if the viewer is blocked
     * @throws \Illuminate\Database\Eloquent\ModelNotFoundException  if $userId is unknown
     */
    // list of another user's friend list
    public function userFriendList($userId)
    {
        try {
            $currentUser = auth('api')->user();

            [$profileUser, $friends] = $this->friendService->userFriendList($currentUser, $userId);

            return $this->success(
                FriendListResource::collection($friends),
                $profileUser->first_name . '\'s friend list fetched successfully.'
            );
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        }
    }

    /**
     * Remove the friendship between the auth user and another user.
     *
     * Delegates to {@see FriendService::unfriend()}.
     *
     * @param  int  $friendId  URL param: the friend to remove
     * @return \Illuminate\Http\JsonResponse  Success, or 400 if the two
     *                                        users are not actually friends
     */
    // user unfriend
    public function unfriend($friendId)
    {
        try {
            $user = auth('api')->user();

            $this->friendService->unfriend($user, $friendId);

            return $this->success(null, 'You have successfully unfriended this user.');
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        }
    }
}
