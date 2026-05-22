<?php

namespace App\Http\Requests\Firebase;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates a request that identifies a Firebase device token by its
 * `device_id` — the fetch and delete token endpoints.
 *
 * Backs `POST /api/firebase/token/get` and `/api/firebase/token/delete`.
 */
class DeviceTokenRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'device_id' => 'required|string',
        ];
    }
}
