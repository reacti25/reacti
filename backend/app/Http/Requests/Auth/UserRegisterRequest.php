<?php

namespace App\Http\Requests\Auth;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

/**
 * Validates the new-account payload for the user registration endpoint.
 *
 * Enforces unique email and phone, name length limits, and a confirmed
 * password. On failure it returns a JSON error envelope (instead of a
 * redirect) so the Flutter client can surface the message directly.
 */
class UserRegisterRequest extends FormRequest
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
     */
    public function rules(): array
    {
        return [
            'first_name' => ['required', 'string', 'min:2', 'max:100'],
            'last_name' => ['nullable', 'string', 'min:2', 'max:100'],
            // Email must not already be registered to another account.
            'email' => ['required', 'string', 'unique:users,email'],
            // Phone is optional but, when given, must also be unique.
            'phone' => ['nullable', 'string', 'unique:users,phone'],
            // 'confirmed' requires a matching password_confirmation field.
            'password' => ['required', 'string', 'confirmed', 'min:8'],
        ];
    }

    /**
     * Get custom validation messages.
     *
     * Provides user-facing copy for each rule so the registration form can
     * show specific errors instead of generic framework defaults.
     *
     * @return array<string, string> "field.rule" => human-readable message.
     */
    public function messages(): array
    {
        return [
            'first_name.required' => 'First name is required.',
            'first_name.min' => 'First name must be at least 2 characters.',
            'first_name.regex' => 'First name can only contain letters and spaces.',
            'last_name.min' => 'Last name must be at least 2 characters.',
            'last_name.regex' => 'Last name can only contain letters and spaces.',
            'email.required' => 'Email address is required.',
            'email.email' => 'Please provide a valid email address.',
            'email.unique' => 'This email address is already registered.',
            'phone.required' => 'Phone number is required.',
            'phone.unique' => 'This phone number is already registered.',
            'password.required' => 'Password is required.',
            'password.min' => 'Password must be at least 8 characters long.',
            'password.confirmed' => 'Password confirmation does not match.',
        ];
    }

    /**
     * Handle a failed validation attempt.
     *
     * Overrides the default redirect behaviour to throw a 422 JSON response,
     * keeping the API contract consistent for the mobile client.
     *
     * @param  \Illuminate\Contracts\Validation\Validator  $validator  The validator carrying the failure messages.
     * @return void
     *
     * @throws \Illuminate\Http\Exceptions\HttpResponseException Always, wrapping the JSON error envelope.
     */
    protected function failedValidation(Validator $validator)
    {
        throw new HttpResponseException(
            response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'errors' => $validator->errors(),
            ], 422)
        );
    }
}
