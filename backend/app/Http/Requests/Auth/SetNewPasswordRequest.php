<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Validates the payload for the "set a new password" step of the
 * password-reset flow.
 *
 * Requires the account email, the reset token issued earlier in the flow,
 * and a confirmed new password before the credentials are updated.
 */
class SetNewPasswordRequest extends FormRequest
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
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            // Email must match an existing account for the reset to apply.
            'email' => ['required', 'email', 'max:50', 'exists:users,email'],
            // Reset token previously issued and emailed to the user.
            'token' => ['required', 'string'],
            // 'confirmed' requires a matching password_confirmation field.
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ];
    }
}
