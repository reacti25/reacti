<?php

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the logout request.
 *
 * Backs `POST /api/logout`. `device_id` is optional — `sometimes`
 * means it is validated only when the client actually sends it, so an
 * absent `device_id` is accepted (the controller then skips removing a
 * Firebase token), exactly as the previous inline `$request->has(...)`
 * guard did.
 */
class LogoutRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'device_id' => 'sometimes|required|string',
        ];
    }
}
