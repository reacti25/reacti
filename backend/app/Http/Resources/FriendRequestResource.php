<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a single friend-request record.
 *
 * Serializes a friend request from the authenticated user's perspective:
 * the embedded `person` is always the *other* party, and `is_sent`
 * indicates the direction. Used as the item resource inside
 * `FriendRequestCollection`.
 */
class FriendRequestResource extends JsonResource
{
    /**
     * Serialize one friend request into the API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with keys:
     *                              - `id`: friend-request record id
     *                              - `person`: the other party's profile
     *                              (id, first_name, last_name, username,
     *                              avatar, full_name)
     *                              - `status`: pending/accepted/declined
     *                              - `sent_at`/`accepted_at`/`declined_at`:
     *                              relative timestamps (null when unset)
     *                              - `is_sent`: true when the auth user sent it
     */
    public function toArray(Request $request): array
    {
        $authId = auth('api')->id();
        // The displayed `person` is whichever party is NOT the viewer.
        $person = $this->sender_id === $authId ? $this->receiver : $this->sender;

        return [
            'id' => $this->id,
            'person' => [
                'id' => $person->id ?? null,
                'first_name' => $person->first_name ?? null,
                'last_name' => $person->last_name ?? null,
                'username' => $person->username ?? null,
                'avatar' => $person?->avatar ? asset($person->avatar) : asset('default/default_image.jpg'),
                'full_name' => trim("{$person->first_name} {$person->last_name}")
                    ?: ($person->username ?? 'Unknown'),
            ],
            'status' => $this->status,
            'sent_at' => $this->created_at?->diffForHumans(),
            'accepted_at' => $this->accepted_at?->diffForHumans(),
            'declined_at' => $this->declined_at?->diffForHumans(),
            'is_sent' => $this->sender_id === $authId,
        ];
    }
}
