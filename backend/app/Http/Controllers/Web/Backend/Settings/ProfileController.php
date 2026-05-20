<?php

namespace App\Http\Controllers\Web\Backend\Settings;

use App\Http\Controllers\Controller;
use App\Services\AdminProfileService;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\View\View;

/**
 * Admin "my profile" settings screen (web guard).
 *
 * Backs the admin profile-settings routes in routes/backend.php: it renders
 * the `backend.layouts.settings.profile_settings` Blade view and handles
 * updating the admin's name/email, changing their password, and uploading
 * a new avatar (the avatar action returns JSON, the others redirect back).
 *
 * This is a thin controller: it validates input, keeps the guard branching
 * (current-password check, upload failure), and shapes the
 * view/redirect/JSON responses. The DB reads and writes live in
 * {@see AdminProfileService}.
 */
class ProfileController extends Controller
{
    /**
     * @param  AdminProfileService  $profileService  Admin-profile business logic.
     */
    public function __construct(private readonly AdminProfileService $profileService)
    {
        parent::__construct();
    }

    /**
     * Show the profile settings page.
     *
     * @param  Request  $request  Query/route: id of the user to display.
     * @return View The `backend.layouts.settings.profile_settings` view.
     */
    public function index(Request $request)
    {
        $user = $this->profileService->find($request->id);

        return view('backend.layouts.settings.profile_settings', compact('user'));
    }

    /**
     * Update the authenticated admin's name and email.
     *
     * @param  Request  $request  Body: name, email.
     * @return RedirectResponse Redirect back with a success/error flash message.
     */
    public function UpdateProfile(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'nullable|max:100|min:2',
            // Email must stay unique, ignoring the current user's own row.
            'email' => 'nullable|email|unique:users,email,'.auth()->user()->id,
        ]);

        if ($validator->fails()) {
            return redirect()->back()->withErrors($validator)->withInput();
        }
        try {
            $this->profileService->updateProfile(auth()->user()->id, $request);
            session()->put('t-success', 'Profile updated successfully');
        } catch (Exception) {
            session()->put('t-error', 'Something went wrong');
        }

        return redirect()->back();
    }

    /**
     * Change the authenticated admin's password.
     *
     * Requires the current password to be supplied and verified before the
     * new one is applied.
     *
     * @param  Request  $request  Body: old_password, password, password_confirmation.
     * @return RedirectResponse Redirect back with a success/error flash message.
     */
    public function UpdatePassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'old_password' => 'required',
            'password' => 'required|confirmed|min:8',
        ]);

        if ($validator->fails()) {
            return redirect()->back()->withErrors($validator)->withInput();
        }
        try {
            $user = Auth::user();
            // Only update the password if the current one was entered correctly.
            if ($this->profileService->updatePassword($user, $request->old_password, $request->password)) {
                return redirect()->back()->with('t-success', 'Password updated successfully');
            } else {
                return redirect()->back()->with('t-error', 'Current password is incorrect');
            }
        } catch (Exception) {
            return redirect()->back()->with('t-error', 'Something went wrong');
        }
    }

    /**
     * Upload and replace the authenticated admin's avatar.
     *
     * Deletes the previous avatar file (if any) before storing the new one.
     *
     * @param  Request  $request  Body: avatar (required image, max 10 MB).
     * @return JsonResponse JSON with the new image URL, or an error payload.
     *
     * @throws Exception Re-thrown internally and caught; surfaces as a JSON error when the upload fails.
     */
    public function UpdateProfilePicture(Request $request)
    {
        $request->validate([
            'avatar' => 'required|image|mimes:jpeg,png,jpg,gif|max:10240',
        ]);

        try {
            $user = Auth::user();
            $imageUrl = $this->profileService->updateProfilePicture($user, $request);

            return response()->json([
                'success' => true,
                'image_url' => $imageUrl,
            ]);
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ]);
        }
    }
}
