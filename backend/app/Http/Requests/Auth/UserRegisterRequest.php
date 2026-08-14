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
            // Age gate. This rule IS the gate — the client's date picker is
            // only UX, so anything that skips the app (curl, an old build)
            // still has to clear it. `before_or_equal` on the cutoff date
            // means someone whose birthday is today passes.
            'date_of_birth' => [
                'required',
                'date',
                'before_or_equal:'.now()->subYears(config('reacti.min_age'))->toDateString(),
            ],
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
            'date_of_birth.required' => 'Your date of birth is required.',
            'date_of_birth.date' => 'Please provide a valid date of birth.',
            'date_of_birth.before_or_equal' => 'You must be at least '.config('reacti.min_age').' to use Reacti.',
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
     * @param  Validator  $validator  The validator carrying the failure messages.
     * @return void
     *
     * @throws HttpResponseException Always, wrapping the JSON error envelope.
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
