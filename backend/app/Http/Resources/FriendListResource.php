<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a single friend in the authenticated user's friend list.
 *
 * Serializes a `User` model (a confirmed friend) into a lightweight
 * profile row. Returned by the friends-list endpoint to render the
 * contacts screen.
 */
class FriendListResource extends JsonResource
{
    /**
     * Serialize one friend into the API response array.
     *
     * @param  Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with keys:
     *                              - `id`: friend user id
     *                              - `name`: trimmed first + last name
     *                              - `username`, `email`, `phone`
     *                              - `avatar`: absolute URL (default image when unset)
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => trim(($this->first_name ?? '').' '.($this->last_name ?? '')),
            'username' => $this->username,
            'email' => $this->email,
            'phone' => $this->phone,
            'avatar' => $this->avatar ? asset($this->avatar) : asset('default/default_image.jpg'),
        ];
    }
}
