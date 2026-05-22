<?php

namespace App\Http\Requests\Group;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the update-group request (name / description / avatar).
 *
 * Backs `POST /api/auth/group/{group_id}/update`.
 */
class UpdateGroupRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'name' => 'nullable|string|max:255',
            'description' => 'nullable|string|max:1000',
            // jpg/jpeg/png/gif only — drop svg.
            'avatar' => 'nullable|image|mimes:jpg,jpeg,png,gif|max:5120',
        ];
    }
}
