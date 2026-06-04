<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

/**
 * API Resource collection for a paginated list of blocked users.
 *
 * Wraps a paginator of `BlockUser` pivot records (each serialized by
 * `BlockedUserResource`) and is returned by the block-list endpoints in
 * the user/settings controllers so the client can render the "Blocked
 * Users" screen with infinite scroll.
 */
class BlockedUserCollection extends ResourceCollection
{
    /**
     * Serialize the blocked-user paginator into the API response array.
     *
     * @param  Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with two keys:
     *                              - `blocked_users`: list of `BlockedUserResource` items
     *                              - `pagination`: total, current_page, last_page, per_page
     */
    public function toArray($request)
    {
        return [
            'blocked_users' => BlockedUserResource::collection($this->collection),
            'pagination' => [
                'total' => $this->total(),
                'current_page' => $this->currentPage(),
                'last_page' => $this->lastPage(),
                'per_page' => $this->perPage(),
            ],
        ];
    }
}
