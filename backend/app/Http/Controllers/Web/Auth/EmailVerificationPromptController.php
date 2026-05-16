<?php

namespace App\Http\Controllers\Web\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * Shows the "please verify your email" prompt.
 *
 * Single-action controller backing the `verification.notice` route. Renders
 * the `auth.verify-email` Blade view for unverified users, or sends verified
 * users straight to the dashboard.
 */
class EmailVerificationPromptController extends Controller
{
    /**
     * Display the email verification prompt.
     *
     * @param  Request  $request  The current request, used to resolve the authenticated user.
     * @return RedirectResponse|View  Dashboard redirect if verified, else the `auth.verify-email` view.
     */
    public function __invoke(Request $request): RedirectResponse|View
    {
        return $request->user()->hasVerifiedEmail()
                    ? redirect()->intended(route('dashboard', absolute: false))
                    : view('auth.verify-email');
    }
}
