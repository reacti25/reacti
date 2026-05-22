<?php

namespace App\Http\Requests\Group;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates a group-message edit request.
 *
 * Backs `POST /api/auth/group/{group_id}/message/{message_id}`.
 */
class EditGroupMessageRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'text' => 'required|string|max:1000',
        ];
    }
}
