<?php

namespace App\Http\Controllers\Web\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

/**
 * Resends the email-address verification link.
 *
 * Serves the `verification.send` route, triggered from the "verify email"
 * prompt when the user requests another verification message. Renders no
 * view of its own — it always redirects.
 */
class EmailVerificationNotificationController extends Controller
{
    /**
     * Send a new email verification notification.
     *
     * @param  Request  $request  The current request, used to resolve the authenticated user.
     * @return RedirectResponse  Redirect to the dashboard if already verified, else back with a sent status.
     */
    public function store(Request $request): RedirectResponse
    {
        // Nothing to do if the address is already verified.
        if ($request->user()->hasVerifiedEmail()) {
            return redirect()->intended(route('dashboard', absolute: false));
        }

        $request->user()->sendEmailVerificationNotification();

        return back()->with('status', 'verification-link-sent');
    }
}
