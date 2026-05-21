<?php

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the request to re-send a registration OTP.
 *
 * Backs `POST /api/resend-register-otp`.
 */
class ResendRegisterOtpRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'email' => 'nullable|email|max:191',
        ];
    }
}
