<?php

namespace App\Http\Controllers\Api\User;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\BlockedUserCollection;
use App\Services\BlockService;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * Manages user blocking for the API.
 *
 * Backs the authenticated block routes: toggling a block on/off and
 * listing blocked users. Blocking a user also tears down any existing
 * friendship and pending friend requests between the two users. This is
 * a thin controller — it validates input and delegates to
 * {@see BlockService}.
 */
class UserBlockController extends Controller
{
    use ApiResponse;

    /**
     * @param  BlockService  $blockService  User-blocking business logic.
     */
    public function __construct(private readonly BlockService $blockService)
    {
        parent::__construct();
    }

    /**
     * Toggle the block state between the auth user and another user.
     *
     * If a block already exists it is removed (unblock). Otherwise,
     * inside a transaction, the block is created and any friend
     * requests and the friendship between the two users are deleted —
     * blocking implies severing the relationship. Self-blocking is
     * rejected. Delegates to {@see BlockService::toggleBlock()}.
     *
     * @param  int  $block_user_id  URL param: the user to block/unblock
     * @return JsonResponse Success (blocked or unblocked),
     *                      404 (unknown user), 400 (self), 500
     */
    public function toggleBlock($block_user_id)
    {
        // Validate URL param
        $validator = Validator::make(['block_user_id' => $block_user_id], [
            'block_user_id' => 'required|exists:users,id',
        ]);

        if ($validator->fails()) {
            return $this->error([], 'User not found.', 404);
        }

        $user = auth('api')->user();

        try {
            $message = $this->blockService->toggleBlock($user, $block_user_id);

            return $this->success([], $message);
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            return $this->error([], 'Something went wrong.', 500);
        }
    }

    /**
     * List the users the authenticated user has blocked.
     *
     * Delegates to {@see BlockService::blockedUsers()}.
     *
     * @param  Request  $request  Query: per_page (default 10)
     * @return JsonResponse Paginated BlockedUserCollection
     */
    public function blockedUsers(Request $request)
    {
        $user = auth('api')->user();

        $blockedUsers = $this->blockService->blockedUsers($user, $request);

        return $this->success(
            new BlockedUserCollection($blockedUsers),
            'Blocked users fetched successfully.'
        );
    }
}
