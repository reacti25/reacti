<?php

namespace App\Http\Resources;

use App\Models\Friend;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a single `User` returned in search results.
 *
 * Serializes a found user's public profile and computes whether the
 * authenticated user is already friends with them. Used as the item
 * resource inside `FindUserCollection`.
 */
class FindUserResource extends JsonResource
{
    /**
     * Serialize one searched user into the API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed>  Array with keys:
     *                               - `id`, `username`, `first_name`, `last_name`
     *                               - `email`, `phone`
     *                               - `avatar`: absolute URL or null
     *                               - `is_friend`: true when the auth user already
     *                                 has a friend row pointing at this user
     */
    public function toArray($request)
    {
        // Resolve the requester to evaluate the friendship flag.
        $authUser = auth('api')->user();

        // True when the auth user has a friend row aimed at this profile.
        $isFriend = Friend::where(function ($q) use ($authUser) {
            $q->where('user_id', $authUser->id)
                ->where('friend_id', $this->id);
        })->exists();

        return [
            'id' => $this->id,
            'username' => $this->username,
            'first_name' => $this->first_name,
            'last_name' => $this->last_name,
            'email' => $this->email,
            'phone' => $this->phone,
            'avatar' => $this->avatar ? url($this->avatar) : null,
            'is_friend' => $isFriend,
        ];
    }
}
