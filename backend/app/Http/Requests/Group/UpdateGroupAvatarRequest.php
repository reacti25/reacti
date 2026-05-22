<?php

namespace App\Http\Requests\Group;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the dedicated update-group-avatar request.
 *
 * Backs `POST /api/auth/group/{group_id}/avatar`.
 */
class UpdateGroupAvatarRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            // jpg/jpeg/png/gif only — drop svg.
            'avatar' => 'required|image|mimes:jpg,jpeg,png,gif|max:5120',
        ];
    }
}
