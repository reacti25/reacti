<?php

namespace App\Http\Requests\Friend;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the body of a report-user request.
 *
 * Backs `POST /api/report/user/{reported_user_id}`. Only the optional
 * body fields are validated here; the controller keeps the inline
 * existence check on the `{reported_user_id}` route param, which
 * returns a resource-specific 404 (not a 422) and so is a
 * resource-guard rather than Form Request validation.
 */
class ReportUserRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'reason' => 'nullable|string|max:255',
            'description' => 'nullable|string',
        ];
    }
}
