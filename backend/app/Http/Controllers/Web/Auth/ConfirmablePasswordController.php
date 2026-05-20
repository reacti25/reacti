<?php

namespace App\Http\Controllers\Web\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

/**
 * Re-confirms the authenticated user's password for sensitive areas.
 *
 * Serves the `password.confirm` routes that guard protected admin actions:
 * shows the confirmation form and verifies the supplied password, recording
 * the confirmation time in the session. Renders the `auth.confirm-password`
 * Blade view.
 */
class ConfirmablePasswordController extends Controller
{
    /**
     * Show the confirm password view.
     *
     * @return View The `auth.confirm-password` Blade view.
     */
    public function show(): View
    {
        return view('auth.confirm-password');
    }

    /**
     * Confirm the user's password.
     *
     * @param  Request  $request  Body: password (the current user's password to verify).
     * @return RedirectResponse Redirect to the originally intended URL once confirmed.
     *
     * @throws \Illuminate\Validation\ValidationException When the supplied password is incorrect.
     */
    public function store(Request $request): RedirectResponse
    {
        // Reject the request if the password does not match the user's own.
        if (! Auth::guard('web')->validate([
            'email' => $request->user()->email,
            'password' => $request->password,
        ])) {
            throw ValidationException::withMessages([
                'password' => __('auth.password'),
            ]);
        }

        // Stamp the confirmation time so the `password.confirm` middleware
        // lets the user through protected routes for the configured window.
        $request->session()->put('auth.password_confirmed_at', time());

        return redirect()->intended(route('dashboard', absolute: false));
    }
}
