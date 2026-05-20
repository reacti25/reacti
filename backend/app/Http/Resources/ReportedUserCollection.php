<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

/**
 * API Resource collection for a paginated list of reported users.
 *
 * Wraps a paginator of user-report records (each serialized by
 * `ReportedUserResource`). Returned by the report endpoints to render
 * the list of users the authenticated user has reported.
 */
class ReportedUserCollection extends ResourceCollection
{
    /**
     * Serialize the reported-user paginator into the API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with two keys:
     *                              - `reported_user`: list of `ReportedUserResource` items
     *                              - `pagination`: total, current_page, last_page, per_page
     */
    public function toArray($request)
    {
        return [
            'reported_user' => ReportedUserResource::collection($this->collection),
            'pagination' => [
                'total' => $this->total(),
                'current_page' => $this->currentPage(),
                'last_page' => $this->lastPage(),
                'per_page' => $this->perPage(),
            ],
        ];
    }
}
