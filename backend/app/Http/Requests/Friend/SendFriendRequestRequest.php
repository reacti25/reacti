<?php

namespace App\Http\Requests\Friend;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates a send-friend-request action.
 *
 * Backs `POST /api/friends/request/send`.
 */
class SendFriendRequestRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'receiver_id' => 'required|exists:users,id',
        ];
    }
}
