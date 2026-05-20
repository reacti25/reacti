<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\ResourceCollection;

/**
 * API Resource collection for a paginated list of users.
 *
 * Wraps a paginator of `User` models, serializing each inline into a
 * lightweight profile row that also exposes friendship/request state.
 * Returned by user-listing endpoints (e.g. people directory, suggestions).
 */
class UserListResource extends ResourceCollection
{
    /**
     * Serialize the user paginator into the API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with two keys:
     *                              - `data`: list of user rows (id, full_name,
     *                              username, avatar, is_friend, is_request_sent)
     *                              - `pagination`: total, current_page, last_page, per_page
     */
    public function toArray($request)
    {
        return [
            'data' => $this->collection->map(function ($user) {
                return [
                    'id' => $user->id,
                    'full_name' => trim("{$user->first_name} {$user->last_name}"),
                    'username' => $user->username,
                    'avatar' => $user->avatar ? url($user->avatar) : null,
                    // Relationship flags supplied by the controller; default false.
                    'is_friend' => $user->is_friend ?? false,
                    'is_request_sent' => $user->is_request_sent ?? false,
                ];
            }),

            'pagination' => [
                'total' => $this->total(),
                'current_page' => $this->currentPage(),
                'last_page' => $this->lastPage(),
                'per_page' => $this->perPage(),
            ],
        ];
    }
}
