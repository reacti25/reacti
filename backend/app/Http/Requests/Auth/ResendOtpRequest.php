<?php

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the "re-send the password-reset OTP" request.
 *
 * Backs `POST /api/resend-otp`.
 */
class ResendOtpRequest extends ApiFormRequest
{
    /**
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'email' => ['required', 'email', 'exists:users,email'],
        ];
    }
}
