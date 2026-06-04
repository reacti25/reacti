<?php

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the password-reset OTP verification request.
 *
 * Backs `POST /api/verify-otp` — exchanges a valid OTP for a one-time
 * reset token.
 */
class VerifyResetOtpRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'email' => 'required|email|exists:users,email',
            'otp' => 'required|digits:4',
        ];
    }
}
