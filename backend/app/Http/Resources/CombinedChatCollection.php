<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

/**
 * API Resource collection for a unified, paginated chat list.
 *
 * Wraps a paginator whose items mix direct chats and group chats (each
 * serialized by `CombinedChatResource`). Returned by the chat-list
 * endpoint so the client can render a single merged conversations screen.
 */
class CombinedChatCollection extends ResourceCollection
{
    /**
     * Serialize the combined chat paginator into the API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with two keys:
     *                              - `chats`: list of `CombinedChatResource` items
     *                              - `pagination`: total, current_page, last_page, per_page
     */
    public function toArray($request)
    {
        // dd($this->total());
        return [
            'chats' => CombinedChatResource::collection($this->collection),
            'pagination' => [
                'total' => $this->total(),
                'current_page' => $this->currentPage(),
                'last_page' => $this->lastPage(),
                'per_page' => $this->perPage(),
            ],
        ];
    }
}
