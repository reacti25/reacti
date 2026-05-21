<?php

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the "email me a password-reset OTP" request.
 *
 * Backs `POST /api/forgot-password`.
 */
class ForgotPasswordRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'email' => 'required|email|exists:users,email',
        ];
    }
}
