<?php

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the "set a new password" request.
 *
 * Backs `POST /api/reset-password`. `confirmed` requires a matching
 * `password_confirmation` field.
 */
class ResetPasswordRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'email' => 'required|email|exists:users,email',
            'token' => 'required|string',
            'password' => 'required|string|min:6|confirmed',
        ];
    }
}
