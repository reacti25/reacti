<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Validates the credentials submitted to the mobile API login endpoint.
 *
 * Backs the JWT-based `POST /api/auth/login` flow used by the Flutter
 * client: it requires an email that already exists in `users`, a password,
 * and optionally a social provider token for OAuth-assisted sign-in.
 */
class LoginRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     *
     * @return bool
     */
    public function authorize()
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, string> Field name => pipe-delimited rule set.
     */
    public function rules()
    {
        return [
            // Email must belong to an existing account so login can fail fast.
            'email' => 'required|email|exists:users,email',
            'password' => 'required|string|min:8',
            // Optional token issued by a social provider for OAuth sign-in.
            'social_token' => 'nullable|string',
        ];
    }

    /**
     * Get custom error messages for validation.
     *
     * Overrides the framework defaults with user-facing copy returned to
     * the mobile client when a rule fails.
     *
     * @return array<string, string> "field.rule" => human-readable message.
     */
    public function messages()
    {
        return [
            'email.required' => 'The email field is required.',
            'email.email' => 'Please enter a valid email address.',
            'email.exists' => 'No account found with this email.',
            'password.required' => 'The password field is required.',
            'password.min' => 'The password must be at least 8 characters.',
        ];
    }
}
