<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Carbon;

/**
 * API Resource for a single `BlockUser` pivot record.
 *
 * Serializes one block relationship together with the embedded blocked
 * user's profile. Used as the item resource inside `BlockedUserCollection`
 * and wherever a single block record is returned to the client.
 */
class BlockedUserResource extends JsonResource
{
    /**
     * Serialize one block record into the API response array.
     *
     * @param  Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with keys:
     *                              - `id`: block record id
     *                              - `block_user_id`: id of the blocked user
     *                              - `created_at`: human-readable time the block was created
     *                              - `blocked_user`: nested profile (id, full_name,
     *                              first_name, last_name, username, avatar)
     */
    public function toArray($request)
    {
        $firstName = $this->blockedUser->first_name ?? '';
        $lastName = $this->blockedUser->last_name ?? '';

        // Build full name safely
        $fullName = trim("$firstName $lastName");
        // Fall back to username, then a placeholder, when no name is set.
        if ($fullName === '') {
            $fullName = $this->blockedUser->username ?? 'Unknown User';
        }

        return [
            'id' => $this->id,
            'block_user_id' => $this->block_user_id,
            'created_at' => Carbon::parse($this->created_at)->diffForHumans(),
            'blocked_user' => [
                'id' => $this->blockedUser->id,
                'full_name' => $fullName,
                'first_name' => $firstName,
                'last_name' => $lastName,
                'username' => $this->blockedUser->username,
                'avatar' => $this->blockedUser->avatar,
            ],
        ];
    }
}
