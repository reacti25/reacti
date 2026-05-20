<?php

namespace App\Http\Requests\Auth;

use Illuminate\Auth\Events\Lockout;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Validates and authenticates credentials for the web (Breeze/session) login.
 *
 * Backs the standard browser-based `POST /login` route. Beyond field
 * validation it owns the credential attempt itself and enforces a
 * per-email-and-IP rate limit (5 attempts) to throttle brute-force logins.
 */
class LoginRequest extends FormRequest
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
            'email' => ['required', 'string', 'email', 'exists:users,email', 'max:50'],
            'password' => ['required', 'string', 'min:8'],
        ];
    }

    /**
     * Attempt to authenticate the request's credentials.
     *
     * Checks the rate limiter first, then tries to log the user in. A failed
     * attempt records a hit against the throttle key; a success clears it.
     *
     * @throws ValidationException When throttled or credentials are invalid.
     */
    public function authenticate(): void
    {
        $this->ensureIsNotRateLimited();

        if (! Auth::attempt($this->only('email', 'password'), $this->boolean('remember'))) {
            RateLimiter::hit($this->throttleKey());

            throw ValidationException::withMessages([
                'email' => trans('auth.failed'),
            ]);
        }

        RateLimiter::clear($this->throttleKey());
    }

    /**
     * Ensure the login request is not rate limited.
     *
     * Allows up to 5 failed attempts per throttle key; once exceeded it
     * fires a Lockout event and blocks further attempts until the cooldown
     * window elapses.
     *
     * @throws ValidationException When the attempt limit has been exceeded.
     */
    public function ensureIsNotRateLimited(): void
    {
        if (! RateLimiter::tooManyAttempts($this->throttleKey(), 5)) {
            return;
        }

        event(new Lockout($this));

        $seconds = RateLimiter::availableIn($this->throttleKey());

        throw ValidationException::withMessages([
            'email' => trans('auth.throttle', [
                'seconds' => $seconds,
                'minutes' => ceil($seconds / 60),
            ]),
        ]);
    }

    /**
     * Get the rate limiting throttle key for the request.
     *
     * Combines the lowercased email and client IP so the limit is scoped
     * per account-and-origin rather than globally.
     *
     * @return string The transliterated "email|ip" throttle key.
     */
    public function throttleKey(): string
    {
        return Str::transliterate(Str::lower($this->string('email')).'|'.$this->ip());
    }
}
