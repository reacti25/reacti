<?php

namespace App\Http\Controllers\Web\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

/**
 * Updates the password of an already authenticated user.
 *
 * Serves the `password.update` route used from the profile/settings page
 * (distinct from the forgotten-password reset flow). Renders no view — it
 * always redirects back with a status.
 */
class PasswordController extends Controller
{
    /**
     * Update the user's password.
     *
     * @param  Request  $request  Body: current_password, password, password_confirmation.
     * @return RedirectResponse Redirect back with a `password-updated` status.
     *
     * @throws ValidationException When the current password is wrong or the new one fails rules.
     */
    public function update(Request $request): RedirectResponse
    {
        // Require the current password and confirm the new one; errors are
        // scoped to the `updatePassword` bag for the inline settings form.
        $validated = $request->validateWithBag('updatePassword', [
            'current_password' => ['required', 'current_password'],
            'password' => ['required', Password::defaults(), 'confirmed'],
        ]);

        $request->user()->update([
            'password' => Hash::make($validated['password']),
        ]);

        return back()->with('status', 'password-updated');
    }
}
