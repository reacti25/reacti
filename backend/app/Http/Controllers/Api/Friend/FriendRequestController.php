<?php

namespace App\Http\Controllers\Api\Friend;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\FriendRequestCollection;
use App\Services\FriendRequestService;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * Manages the friend-request lifecycle for the API.
 *
 * Backs the authenticated friend-request routes: sending, cancelling,
 * accepting, and declining requests, plus listing incoming and sent
 * requests. This is a thin controller — it validates input and
 * delegates to {@see FriendRequestService}.
 */
class FriendRequestController extends Controller
{
    use ApiResponse;

    /**
     * @param  FriendRequestService  $friendRequestService  Friend-request business logic.
     */
    public function __construct(private readonly FriendRequestService $friendRequestService)
    {
        parent::__construct();
    }

    /**
     * Send a friend request to another user.
     *
     * Delegates to {@see FriendRequestService::sendRequest()}.
     *
     * @param  Request  $request  Body: receiver_id (must exist in users)
     * @return \Illuminate\Http\JsonResponse Success, 400 (self),
     *                                       409 (already exists), 422, 500
     */
    public function sendRequest(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'receiver_id' => 'required|exists:users,id',
        ]);

        if ($validator->fails()) {
            return $this->error([], $validator->errors()->first(), 422);
        }

        $sender = auth('api')->user();
        $receiverId = $request->receiver_id;

        try {
            $this->friendRequestService->sendRequest($sender, $receiverId);

            return $this->success([], 'Friend request sent successfully.');
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            return $this->error([], 'Something went wrong: '.$e->getMessage(), 500);
        }
    }

    /**
     * Cancel a pending friend request the auth user has sent.
     *
     * Delegates to {@see FriendRequestService::cancelRequest()}.
     *
     * @param  Request  $request  Body: receiver_id (the request's recipient)
     * @return \Illuminate\Http\JsonResponse Success, 404 if no pending
     *                                       request, 422 on validation, 500
     */
    public function cancelRequest(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'receiver_id' => 'required|exists:users,id',
        ]);

        if ($validator->fails()) {
            return $this->error([], $validator->errors()->first(), 422);
        }

        $user = auth('api')->user();

        try {
            $this->friendRequestService->cancelRequest($user, $request->receiver_id);

            return $this->success([], 'Friend request canceled successfully.');
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            return $this->error([], 'Something went wrong: '.$e->getMessage(), 500);
        }
    }

    /**
     * Accept a pending friend request addressed to the auth user.
     *
     * Delegates to {@see FriendRequestService::acceptRequest()}.
     *
     * @param  Request  $request  Body: sender_id (who sent the request)
     * @return \Illuminate\Http\JsonResponse Success, 404 if no pending
     *                                       request, 422 on validation, 500
     */
    public function acceptRequest(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'sender_id' => 'required|exists:users,id',
        ]);

        if ($validator->fails()) {
            return $this->error([], $validator->errors()->first(), 422);
        }

        $receiver = auth('api')->user();

        try {
            $this->friendRequestService->acceptRequest($receiver, $request->sender_id);

            return $this->success([], 'Friend request accepted successfully.');
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            return $this->error([], 'Something went wrong: '.$e->getMessage(), 500);
        }
    }

    /**
     * Decline a pending friend request addressed to the auth user.
     *
     * Delegates to {@see FriendRequestService::declineRequest()}.
     *
     * @param  Request  $request  Body: sender_id (who sent the request)
     * @return \Illuminate\Http\JsonResponse Success, 404 if no pending
     *                                       request, 422 on validation, 500
     */
    public function declineRequest(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'sender_id' => 'required|exists:users,id',
        ]);

        if ($validator->fails()) {
            return $this->error([], $validator->errors()->first(), 422);
        }

        $receiver = auth('api')->user();

        try {
            $this->friendRequestService->declineRequest($receiver, $request->sender_id);

            return $this->success([], 'Friend request declined.');
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            return $this->error([], 'Something went wrong: '.$e->getMessage(), 500);
        }
    }

    /**
     * List the auth user's incoming pending friend requests.
     *
     * Delegates to {@see FriendRequestService::getRequests()}.
     *
     * @param  Request  $request  Query: per_page (default 10)
     * @return \Illuminate\Http\JsonResponse Paginated FriendRequestCollection
     */
    public function getRequests(Request $request)
    {
        $user = auth('api')->user();

        $perPage = $request->get('per_page', 10);

        $requests = $this->friendRequestService->getRequests($user, $perPage);

        return $this->success(
            new FriendRequestCollection($requests),
            'Incoming friend requests fetched successfully.'
        );
    }

    /**
     * List the pending friend requests the auth user has sent.
     *
     * Delegates to {@see FriendRequestService::getSentRequests()}.
     *
     * @param  Request  $request  Query: per_page (default 10)
     * @return \Illuminate\Http\JsonResponse Paginated FriendRequestCollection
     */
    public function getSentRequests(Request $request)
    {
        $user = auth('api')->user();

        $perPage = $request->get('per_page', 10);

        $sentRequests = $this->friendRequestService->getSentRequests($user, $perPage);

        return $this->success(
            new FriendRequestCollection($sentRequests),
            'Sent friend requests fetched successfully.'
        );
    }
}
