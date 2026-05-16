<?php

namespace App\Http\Controllers\Web\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Auth\Events\Verified;
use Illuminate\Foundation\Auth\EmailVerificationRequest;
use Illuminate\Http\RedirectResponse;

/**
 * Confirms an email address from the signed verification link.
 *
 * Single-action controller backing the `verification.verify` route reached
 * when a user clicks the link in their verification email. Marks the
 * address verified and redirects to the dashboard; renders no view.
 */
class VerifyEmailController extends Controller
{
    /**
     * Mark the authenticated user's email address as verified.
     *
     * @param  EmailVerificationRequest  $request  Signed request that validates the verification hash.
     * @return RedirectResponse  Redirect to the dashboard with a `verified=1` query flag.
     */
    public function __invoke(EmailVerificationRequest $request): RedirectResponse
    {
        // Already verified — skip straight to the dashboard.
        if ($request->user()->hasVerifiedEmail()) {
            return redirect()->intended(route('dashboard', absolute: false).'?verified=1');
        }

        // Mark verified; only fire the `Verified` event when the state
        // actually changed (markEmailAsVerified returns false if unchanged).
        if ($request->user()->markEmailAsVerified()) {
            event(new Verified($request->user()));
        }

        return redirect()->intended(route('dashboard', absolute: false).'?verified=1');
    }
}
