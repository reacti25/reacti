<?php

namespace App\Http\Requests\Firebase;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates a Firebase device-token registration.
 *
 * Backs `POST /api/firebase/token`.
 */
class StoreFirebaseTokenRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'token' => 'required|string',
            'device_id' => 'required|string',
        ];
    }
}
