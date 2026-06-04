<?php

namespace App\Http\Requests\Group;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the create-group request.
 *
 * Backs `POST /api/auth/group/create`.
 */
class CreateGroupRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'name' => 'required|string|max:255',
            'description' => 'nullable|string|max:1000',
            // image + mimes intersection: jpg/jpeg/png/gif only (drops
            // svg, which the image rule otherwise allows).
            'avatar' => 'nullable|image|mimes:jpg,jpeg,png,gif|max:5120',
            'members' => 'required|array|min:1',
            'members.*' => 'exists:users,id',
        ];
    }
}
