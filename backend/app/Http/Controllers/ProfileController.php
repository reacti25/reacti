<?php

namespace App\Http\Controllers;

use App\Http\Requests\ProfileUpdateRequest;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Redirect;
use Illuminate\View\View;

/**
 * Handles the authenticated user's own account profile (web/session side).
 *
 * Backs the Breeze-style `profile.*` routes — viewing the profile form,
 * updating personal details, and self-deleting the account. Renders the
 * `profile.edit` Blade view.
 */
class ProfileController extends Controller
{
    /**
     * Display the user's profile form.
     *
     * @param  Request  $request  The current request, used to resolve the authenticated user.
     * @return View The `profile.edit` Blade view with the current user.
     */
    public function edit(Request $request): View
    {
        return view('profile.edit', [
            'user' => $request->user(),
        ]);
    }

    /**
     * Update the user's profile information.
     *
     * @param  ProfileUpdateRequest  $request  Form-request carrying the validated profile fields.
     * @return RedirectResponse Redirect back to the profile form with a `profile-updated` status.
     */
    public function update(ProfileUpdateRequest $request): RedirectResponse
    {
        $request->user()->fill($request->validated());

        // Changing the email invalidates prior verification, so force the
        // user to re-verify by clearing the verified timestamp.
        if ($request->user()->isDirty('email')) {
            $request->user()->email_verified_at = null;
        }

        $request->user()->save();

        return Redirect::route('profile.edit')->with('status', 'profile-updated');
    }

    /**
     * Delete the user's account.
     *
     * Requires the user to re-enter their current password as a
     * confirmation step before the account is permanently removed.
     *
     * @param  Request  $request  Body: password (must match the current password).
     * @return RedirectResponse Redirect to the site root after logout and deletion.
     */
    public function destroy(Request $request): RedirectResponse
    {
        // Re-confirm identity with the current password before deleting;
        // errors are scoped to the `userDeletion` bag for the inline form.
        $request->validateWithBag('userDeletion', [
            'password' => ['required', 'current_password'],
        ]);

        $user = $request->user();

        Auth::logout();

        $user->delete();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return Redirect::to('/');
    }
}
