<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a single user-report record.
 *
 * Serializes one report (reason, description, timestamp) together with
 * the embedded reported user's profile. Used as the item resource inside
 * `ReportedUserCollection`.
 */
class ReportedUserResource extends JsonResource
{
    /**
     * Serialize one report record into the API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed>  Array with keys:
     *                               - `id`: report record id
     *                               - `reported_user_id`: id of the reported user
     *                               - `reason`, `description`: report content
     *                               - `created_at`: human-readable report time
     *                               - `reported_user`: nested profile (id, full_name,
     *                                 first_name, last_name, username, avatar)
     */
    public function toArray($request)
    {
        $firstName = $this->reportedUser->first_name ?? '';
        $lastName  = $this->reportedUser->last_name ?? '';

        $fullName = trim("$firstName $lastName");
        // Fall back to username, then a placeholder, when no name is set.
        if ($fullName === '') {
            $fullName = $this->reportedUser->username ?? 'Unknown User';
        }

        return [
            'id'               => $this->id,
            'reported_user_id' => $this->reported_user_id,
            'reason'           => $this->reason,
            'description'      => $this->description,
            'created_at'       => Carbon::parse($this->created_at)->diffForHumans(),
            'reported_user'    => [
                'id'         => $this->reportedUser->id,
                'full_name'  => $fullName,
                'first_name' => $firstName,
                'last_name'  => $lastName,
                'username'   => $this->reportedUser->username,
                'avatar'     => $this->reportedUser->avatar,
            ],
        ];
    }
}
