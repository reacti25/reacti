<?php

namespace App\Http\Requests\Group;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the bulk delete-group-messages request.
 *
 * Backs `DELETE /api/auth/group/{group_id}/messages`.
 */
class DeleteGroupMessagesRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'message_ids' => 'required|array|min:1',
            'message_ids.*' => 'exists:group_messages,id',
        ];
    }
}
