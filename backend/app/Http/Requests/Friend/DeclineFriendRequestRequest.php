<?php

namespace App\Http\Requests\Friend;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates a decline-friend-request action.
 *
 * Backs `POST /api/friends/request/decline`.
 */
class DeclineFriendRequestRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'sender_id' => 'required|exists:users,id',
        ];
    }
}
