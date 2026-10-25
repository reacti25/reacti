<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;
use Illuminate\Pagination\LengthAwarePaginator;

/**
 * A page of items under a named key, plus the `pagination` block the app reads.
 *
 * Replaces five near-identical collections that differed only in the key and
 * the item resource. The output shape is unchanged:
 * `{<key>: [...], pagination: {total, current_page, last_page, per_page}}`.
 *
 * @example new PaginatedCollection($paginator, 'blocked_users', BlockedUserResource::class)
 */
class PaginatedCollection extends ResourceCollection
{
    /**
     * @param  LengthAwarePaginator  $resource  The page to serialize.
     * @param  string  $itemsKey  Name of the items key the app expects (e.g. `chats`).
     * @param  class-string<\Illuminate\Http\Resources\Json\JsonResource>  $itemResource  Resource for each item.
     */
    public function __construct($resource, private string $itemsKey, private string $itemResource)
    {
        parent::__construct($resource);
    }

    /**
     * Serialize the page into `{<key>: [...], pagination: {...}}`.
     *
     * @param  Request  $request  The incoming HTTP request.
     * @return array<string, mixed>
     */
    public function toArray($request)
    {
        return [
            $this->itemsKey => $this->itemResource::collection($this->collection),
            'pagination' => [
                'total' => $this->total(),
                'current_page' => $this->currentPage(),
                'last_page' => $this->lastPage(),
                'per_page' => $this->perPage(),
            ],
        ];
    }
}
