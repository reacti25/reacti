<?php

namespace App\Http\Requests\Group;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the add-members-to-group request.
 *
 * Backs `POST /api/auth/group/{group_id}/members`.
 */
class AddGroupMembersRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'members' => 'required|array|min:1',
            'members.*' => 'exists:users,id',
        ];
    }
}
