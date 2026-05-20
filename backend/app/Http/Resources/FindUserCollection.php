<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

/**
 * API Resource collection for user search results.
 *
 * Wraps a collection of `User` models matched by the user-search/find
 * endpoint, serializing each through `FindUserResource`. Used to populate
 * the "find people" / add-friend search screen.
 */
class FindUserCollection extends ResourceCollection
{
    /**
     * Serialize the matched users into the API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with a single `data` key holding
     *                              the list of `FindUserResource` items.
     */
    public function toArray($request)
    {
        return [
            'data' => $this->collection->map(fn ($user) => new FindUserResource($user)),
        ];
    }
}
