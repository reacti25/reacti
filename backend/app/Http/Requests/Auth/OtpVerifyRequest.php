<?php

namespace App\Http\Requests\Auth;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Validates the email plus one-time password submitted to the OTP
 * verification endpoint.
 *
 * Used by the password-reset / account-confirmation flow to confirm the
 * user controls the mailbox before a reset token or session is granted.
 */
class OtpVerifyRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'email' => ['required', 'email', 'max:50'],
            // OTP must be exactly 4 numeric digits, matching the code length sent by email.
            'otp' => ['required', 'digits:4'],
        ];
    }
}
