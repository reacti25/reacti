<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a single `User`'s profile.
 *
 * Serializes a user's public profile fields plus aggregate counts
 * (`friends_count`, `groups_count`). Returned by profile endpoints
 * (own profile, viewing another user) across the app.
 */
class UserResource extends JsonResource
{
    /**
     * Serialize the user profile into the API response array.
     *
     * @param  Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with keys:
     *                              - `id`
     *                              - `full_name`: first + last name
     *                              - `first_name`, `last_name`, `username`
     *                              - `email`, `bio`, `phone`
     *                              - `avatar`: absolute URL (default image when unset)
     *                              - `total_friends`: friends_count aggregate (0 default)
     *                              - `total_groups`: groups_count aggregate (0 default)
     *                              - `created_at`: relative join time (null when unset)
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'full_name' => $this->first_name.' '.$this->last_name,
            'first_name' => $this->first_name,
            'last_name' => $this->last_name ?? null,
            'username' => $this->username ?? null,
            'email' => $this->email ?? null,
            'bio' => $this->bio ?? null,
            'phone' => $this->phone ?? null,
            'avatar' => $this->avatar ? asset($this->avatar) : asset('default/default_image.jpg'),
            'total_friends' => $this->friends_count ?? 0,
            'total_groups' => $this->groups_count ?? 0,
            // Read-receipts preference (default on); old clients ignore it.
            'read_receipts' => (bool) ($this->read_receipts ?? true),
            'created_at' => $this->created_at ? $this->created_at->diffForHumans() : null,
        ];
    }
}
