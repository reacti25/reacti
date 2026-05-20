<?php

namespace App\Http\Controllers\Api\Friend;

use App\Http\Controllers\Controller;
use App\Http\Resources\FindUserCollection;
use App\Services\FriendService;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;

/**
 * Discovers Reacti users from a caller's phone contacts.
 *
 * Backs the authenticated friend-discovery route: the client uploads
 * its address-book phone numbers and gets back the users registered
 * with those numbers, excluding the caller and anyone they have
 * blocked, with an `is_friend` flag for each match. This is a thin
 * controller — it validates input and delegates to {@see FriendService}.
 */
class FindFriendController extends Controller
{
    use ApiResponse;

    /**
     * @param  FriendService  $friendService  Friend/contact business logic.
     */
    public function __construct(private readonly FriendService $friendService)
    {
        parent::__construct();
    }

    /**
     * Match uploaded phone contacts against registered users.
     *
     * Each submitted number is normalized to a `+`-prefixed digits
     * string before matching. Results exclude the caller and anyone
     * they have blocked, and an optional `search` query further
     * filters by name/email/phone. Delegates to {@see FriendService::findContacts()}.
     *
     * @param  Request  $request  Body: contacts (array of phone strings);
     *                            Query: search (optional)
     * @return \Illuminate\Http\JsonResponse Paginated FindUserCollection,
     *                                       each entry flagged is_friend
     *
     * @throws \Illuminate\Validation\ValidationException if contacts is missing/empty
     */
    public function findContacts(Request $request)
    {
        $user = auth('api')->user();

        $validated = $request->validate([
            'contacts' => 'required|array|min:1',
            'contacts.*' => 'string',
        ]);

        // Search keyword from query params
        $search = $request->query('search');

        $users = $this->friendService->findContacts($user, $validated['contacts'], $search);

        return $this->success(
            new FindUserCollection($users),
            'Matching contacts fetched successfully.'
        );
    }
}
