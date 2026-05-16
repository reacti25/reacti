<?php

namespace App\Http\Controllers\Web\Backend\Settings;

use Exception;
use App\Models\User;
use App\Helper\Helper;
use Illuminate\View\View;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Validator;

/**
 * Admin "my profile" settings screen (web guard).
 *
 * Backs the admin profile-settings routes in routes/backend.php: it renders
 * the `backend.layouts.settings.profile_settings` Blade view and handles
 * updating the admin's name/email, changing their password, and uploading
 * a new avatar (the avatar action returns JSON, the others redirect back).
 */
class ProfileController extends Controller
{
    /**
     * Show the profile settings page.
     *
     * @param  Request  $request  Query/route: id of the user to display.
     * @return \Illuminate\View\View  The `backend.layouts.settings.profile_settings` view.
     */
    public function index(Request $request)
    {
        $user = User::find($request->id);
        return view('backend.layouts.settings.profile_settings', compact('user'));
    }

    /**
     * Update the authenticated admin's name and email.
     *
     * @param  Request  $request  Body: name, email.
     * @return \Illuminate\Http\RedirectResponse  Redirect back with a success/error flash message.
     */
    public function UpdateProfile(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name'  => 'nullable|max:100|min:2',
            // Email must stay unique, ignoring the current user's own row.
            'email' => 'nullable|email|unique:users,email,' . auth()->user()->id,
        ]);

        if ($validator->fails()) {
            return redirect()->back()->withErrors($validator)->withInput();
        }
        try {
            $user        = User::find(auth()->user()->id);
            $user->name  = $request->name;
            $user->email = $request->email;

            $user->save();
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
     * @return \Illuminate\Http\RedirectResponse  Redirect back with a success/error flash message.
     */
    public function UpdatePassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'old_password' => 'required',
            'password'     => 'required|confirmed|min:8',
        ]);

        if ($validator->fails()) {
            return redirect()->back()->withErrors($validator)->withInput();
        }
        try {
            $user = Auth::user();
            // Only update the password if the current one was entered correctly.
            if (Hash::check($request->old_password, $user->password)) {
                $user->password = Hash::make($request->password);
                $user->save();

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
     * @return \Illuminate\Http\JsonResponse  JSON with the new image URL, or an error payload.
     *
     * @throws \Exception  Re-thrown internally and caught; surfaces as a JSON error when the upload fails.
     */
    public function UpdateProfilePicture(Request $request)
    {
        $request->validate([
            'avatar' => 'required|image|mimes:jpeg,png,jpg,gif|max:10240',
        ]);

        try {
            $user      = Auth::user();
            $image     = $request->file('avatar');
            // Unique filename so a re-upload never collides with old files.
            $imageName = time() . '.' . $image->getClientOriginalExtension();

            //? Check if there's an existing profile picture
            if ($user->avatar && file_exists(public_path($user->avatar))) {
                Helper::deleteImage(public_path($user->avatar));
            }

            //* Use the Helper class to handle the file upload
            $imagePath = Helper::uploadImage($image, 'profile', $imageName);

            if ($imagePath === null) {
                throw new Exception('Failed to upload image.');
            }

            //! Update user's avatar with the new image path
            $user->avatar = $imagePath;
            $user->save();

            return response()->json([
                'success'   => true,
                'image_url' => asset($imagePath),
            ]);
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ]);
        }
    }
}
