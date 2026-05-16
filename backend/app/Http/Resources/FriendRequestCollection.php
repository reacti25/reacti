<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

/**
 * API Resource collection for a paginated list of friend requests.
 *
 * Wraps a paginator of friend-request records (each serialized by
 * `FriendRequestResource`). Returned by the friend-request endpoints to
 * render the incoming/outgoing requests screen with pagination.
 */
class FriendRequestCollection extends ResourceCollection
{
    /**
     * Serialize the friend-request paginator into the API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed>  Array with two keys:
     *                               - `requests`: list of `FriendRequestResource` items
     *                               - `pagination`: total, current_page, last_page, per_page
     */
    public function toArray($request)
    {
        return [
            'requests' => FriendRequestResource::collection($this->collection),
            'pagination' => [
                'total'        => $this->total(),
                'current_page' => $this->currentPage(),
                'last_page'    => $this->lastPage(),
                'per_page'     => $this->perPage(),
            ],
        ];
    }
}
