<?php

namespace App\Http\Requests\Friend;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates an accept-friend-request action.
 *
 * Backs `POST /api/friends/request/accept`.
 */
class AcceptFriendRequestRequest extends ApiFormRequest
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
