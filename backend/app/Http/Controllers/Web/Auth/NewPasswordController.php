<?php

namespace App\Http\Controllers\Web\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules;
use Illuminate\View\View;

/**
 * Handles the final step of the password reset flow.
 *
 * Serves the `password.reset` / `password.store` routes: shows the reset
 * form (reached from the emailed reset link) and applies the new password
 * after validating the signed token. Renders the `auth.reset-password`
 * Blade view.
 */
class NewPasswordController extends Controller
{
    /**
     * Display the password reset view.
     *
     * @param  Request  $request  The current request, passed to the view so the form can echo the token/email.
     * @return View  The `auth.reset-password` Blade view.
     */
    public function create(Request $request): View
    {
        return view('auth.reset-password', ['request' => $request]);
    }

    /**
     * Handle an incoming new password request.
     *
     * Verifies the reset token, hashes and persists the new password, and
     * fires the `PasswordReset` event on success.
     *
     * @param  Request  $request  Body: token, email, password, password_confirmation.
     * @return RedirectResponse  Redirect to login on success, or back with errors on failure.
     *
     * @throws \Illuminate\Validation\ValidationException  When the submitted fields fail validation.
     */
    public function store(Request $request): RedirectResponse
    {
        $request->validate([
            'token' => ['required'],
            'email' => ['required', 'email'],
            'password' => ['required', 'confirmed', Rules\Password::defaults()],
        ]);

        // Here we will attempt to reset the user's password. If it is successful we
        // will update the password on an actual user model and persist it to the
        // database. Otherwise we will parse the error and return the response.
        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function ($user) use ($request) {
                // Persist the hashed password and rotate the remember token
                // so any previously issued "remember me" cookies stop working.
                $user->forceFill([
                    'password' => Hash::make($request->password),
                    'remember_token' => Str::random(60),
                ])->save();

                event(new PasswordReset($user));
            }
        );

        // If the password was successfully reset, we will redirect the user back to
        // the application's home authenticated view. If there is an error we can
        // redirect them back to where they came from with their error message.
        return $status == Password::PASSWORD_RESET
                    ? redirect()->route('login')->with('status', __($status))
                    : back()->withInput($request->only('email'))
                        ->withErrors(['email' => __($status)]);
    }
}
