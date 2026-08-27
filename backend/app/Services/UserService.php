<?php

namespace App\Services;

use App\Http\Controllers\Api\User\UserController;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Business logic for reading user profiles and the user directory.
 *
 * Extracted from {@see UserController} so the
 * controller only validates input and shapes responses. These methods have
 * no expected business-rule failures of their own — the "User not found"
 * case in {@see self::userDetais()} is returned to the controller as a null
 * lookup so the controller can reproduce its pre-existing HTTP-200 envelope.
 */
class UserService
{
    /**
     * Shortest username query that returns anything.
     *
     * Below this the result set stops being a search and becomes a slice of
     * the directory — one letter used to match every username containing it.
     */
    public const MIN_USERNAME_SEARCH = 3;

    /**
     * Most results a username search may return.
     *
     * A bound on how much of the directory one query can reveal, however
     * common the prefix.
     */
    public const MAX_USERNAME_RESULTS = 20;

    /**
     * Look up a single user's public profile by id.
     *
     * Returns `null` when the user does not exist; the controller maps
     * that to its (quirky) HTTP-200 "User not found." response.
     *
     * @param  int  $id  The user id to fetch.
     * @return User|null The user, or null when no row matches.
     */
    public function userDetais($id): ?User
    {
        return User::find($id);
    }

    /**
     * Order username matches by how close they already are to the searcher.
     *
     * Friends first, then friends-of-friends, then everyone else; alphabetical
     * inside each band so the order is stable between identical queries.
     *
     * This is the half of the model that makes a capped result set useful
     * rather than arbitrary: with at most a handful of rows returned, the
     * people the searcher actually knows have to be among them, or the cap
     * hides the very person they were looking for.
     *
     * @param  Builder  $query  The query to order.
     * @param  User  $currentUser  The authenticated user.
     * @param  Collection  $friendIds  Ids of the searcher's friends.
     */
    private function orderBySocialDistance($query, User $currentUser, $friendIds): void
    {
        $friends = $friendIds->all();

        // Friends-of-friends: anyone linked to one of my friends, minus my own
        // friends and me. Empty when I have no friends, which is the common
        // case on a new account — hence the guards below.
        $fof = [];
        if ($friends !== []) {
            $fof = DB::table('friends')
                ->where(function ($q) use ($friends) {
                    $q->whereIn('user_id', $friends)->orWhereIn('friend_id', $friends);
                })
                ->get(['user_id', 'friend_id'])
                ->flatMap(fn ($row) => [$row->user_id, $row->friend_id])
                ->unique()
                ->reject(fn ($id) => $id === $currentUser->id || in_array($id, $friends, true))
                ->values()
                ->all();
        }

        // Bind through the query builder rather than interpolating: these ids
        // come from the database, but a raw list built by string concatenation
        // is a habit worth not having.
        if ($friends !== []) {
            $query->orderByRaw(
                'CASE WHEN id IN ('.implode(',', array_fill(0, count($friends), '?')).') THEN 0 ELSE 1 END',
                $friends,
            );
        }
        if ($fof !== []) {
            $query->orderByRaw(
                'CASE WHEN id IN ('.implode(',', array_fill(0, count($fof), '?')).') THEN 0 ELSE 1 END',
                $fof,
            );
        }
        $query->orderBy('username');
    }

    /**
     * Browse / search the user directory for the authenticated user.
     *
     * Excludes the auth user. Friend ids and pending sent-request ids are
     * preloaded once so each result can be flagged `is_friend` and
     * `is_request_sent` without an N+1 query.
     *
     * @param  User  $currentUser  The authenticated user.
     * @param  Request  $request  Query: search (optional), per_page (default 15),
     *                            mode ('username' for username-only discovery).
     * @return LengthAwarePaginator Paginated
     *                              user matches.
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
        $search = trim((string) $request->get('search', ''));

        // Discovery mode. `mode=username` (used by the add-friend search) matches
        // the username alone and requires a query, so users can't browse the whole
        // directory or surface strangers by name/phone. Any other value keeps the
        // legacy multi-field match (incl. phone) for existing/other callers.
        $usernameOnly = $request->get('mode') === 'username';

        $query = User::query()
            ->where('id', '!=', $currentUser->id)
            ->select(['id', 'first_name', 'last_name', 'username', 'avatar']);

        if ($usernameOnly) {
            // A substring match on one letter returned every username
            // containing it, which is browsing the directory, not searching it.
            // Reacti is not a place to be discovered by strangers: opening a
            // message turns the recipient's camera on, so being reachable is a
            // heavier thing here than a follow request.
            //
            // PREFIX from at least self::MIN_USERNAME_SEARCH characters, capped
            // at self::MAX_USERNAME_RESULTS. You can find someone whose handle
            // you already roughly know, and no one else.
            if (mb_strlen($search) < self::MIN_USERNAME_SEARCH) {
                $query->whereRaw('1 = 0');
            } else {
                // Handles are stored with their leading '@'; typing it or not
                // must find the same person.
                $prefix = ltrim($search, '@');
                $query->where(function ($sq) use ($prefix) {
                    $sq->where('username', 'like', "@{$prefix}%")
                        ->orWhere('username', 'like', "{$prefix}%");
                });
                $this->orderBySocialDistance($query, $currentUser, $friendIds);
                $perPage = min((int) $perPage, self::MAX_USERNAME_RESULTS);
            }
        } elseif ($search !== '') {
            $query->where(function ($sq) use ($search) {
                $sq->where('first_name', 'like', "%{$search}%")
                    ->orWhere('last_name', 'like', "%{$search}%")
                    ->orWhere('username', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhereRaw("CONCAT(first_name, ' ', last_name) LIKE ?", ["%{$search}%"]);
            });
        }

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
