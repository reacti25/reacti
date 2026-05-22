<?php

namespace App\Http\Requests\Friend;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates a cancel-friend-request action.
 *
 * Backs `POST /api/friends/request/cancel`.
 */
class CancelFriendRequestRequest extends ApiFormRequest
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
