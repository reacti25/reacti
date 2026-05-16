<?php

namespace App\Http\Controllers\Web\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Password;
use Illuminate\View\View;

/**
 * Handles the first step of the forgotten-password flow.
 *
 * Serves the `password.request` / `password.email` routes: shows the
 * "forgot password" form and emails a reset link to the supplied address.
 * Renders the `auth.forgot-password` Blade view.
 */
class PasswordResetLinkController extends Controller
{
    /**
     * Display the password reset link request view.
     *
     * @return View  The `auth.forgot-password` Blade view.
     */
    public function create(): View
    {
        return view('auth.forgot-password');
    }

    /**
     * Handle an incoming password reset link request.
     *
     * @param  Request  $request  Body: email (the address to send the reset link to).
     * @return RedirectResponse  Redirect back with either a sent status or validation errors.
     *
     * @throws \Illuminate\Validation\ValidationException  When the email field fails validation.
     */
    public function store(Request $request): RedirectResponse
    {
        $request->validate([
            'email' => ['required', 'email'],
        ]);

        // We will send the password reset link to this user. Once we have attempted
        // to send the link, we will examine the response then see the message we
        // need to show to the user. Finally, we'll send out a proper response.
        $status = Password::sendResetLink(
            $request->only('email')
        );

        return $status == Password::RESET_LINK_SENT
                    ? back()->with('status', __($status))
                    : back()->withInput($request->only('email'))
                        ->withErrors(['email' => __($status)]);
    }
}
