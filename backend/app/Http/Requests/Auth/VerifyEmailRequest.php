<?php

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates the registration-OTP confirmation request.
 *
 * Backs `POST /api/email-verify`. Only the OTP is validated here; the
 * email is resolved from the request body by the controller.
 */
class VerifyEmailRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'otp' => 'required|digits:4',
        ];
    }
}
