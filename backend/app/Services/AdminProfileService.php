<?php

namespace App\Services;

use App\Helpers\Helper;
use App\Http\Controllers\Web\Backend\Settings\ProfileController;
use App\Models\User;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

/**
 * Business logic for the admin "my profile" settings screen.
 *
 * Extracted from {@see ProfileController}
 * so the controller only validates input and shapes the view/redirect/JSON
 * responses. The service performs the DB reads and writes; the controller
 * keeps the guard branching (current-password check, upload failure) so the
 * exact flash messages and JSON payloads are unchanged.
 *
 * Note: {@see self::updateProfile()} maps the form's single "name"
 * field onto the user's `first_name` column (the schema has no `name`).
 */
class AdminProfileService
{
    /**
     * Find a user by id (for the profile screen).
     *
     * @param  int|string|null  $id  The id of the user to display.
     * @return User|null The user, or null when missing.
     */
    public function find($id): ?User
    {
        return User::find($id);
    }

    /**
     * Update the authenticated admin's name and email.
     *
     * The form's single "name" field maps to the user's `first_name`
     * column; the schema has no `name` column. Pre-fix the assignment
     * went to `$user->name` and threw QueryException — silently
     * swallowed into a `t-error` flash, so the endpoint redirected 302
     * without ever persisting anything.
     *
     * @param  int|string  $userId  The authenticated admin's id.
     * @param  Request  $request  The incoming request (name, email).
     */
    public function updateProfile($userId, Request $request): void
    {
        $user = User::find($userId);
        $user->first_name = $request->name;
        $user->email = $request->email;

        $user->save();
    }

    /**
     * Change the authenticated admin's password.
     *
     * Verifies the supplied current password before applying the new one.
     * Returns false (without writing) when the current password is wrong so
     * the controller can emit its "Current password is incorrect" flash.
     *
     * @param  User  $user  The authenticated admin.
     * @param  string  $oldPassword  The supplied current password.
     * @param  string  $newPassword  The new password to set.
     * @return bool True when the password was updated, false on a wrong current password.
     */
    public function updatePassword(User $user, string $oldPassword, string $newPassword): bool
    {
        // Only update the password if the current one was entered correctly.
        if (Hash::check($oldPassword, $user->password)) {
            $user->password = Hash::make($newPassword);
            $user->save();

            return true;
        }

        return false;
    }

    /**
     * Upload and replace the authenticated admin's avatar.
     *
     * Deletes the previous avatar file (if any) before storing the new one.
     * Throws when the upload fails so the controller can surface the JSON
     * error payload — exactly as the pre-refactor controller did.
     *
     * @param  User  $user  The authenticated admin.
     * @param  Request  $request  The incoming request (avatar file).
     * @return string The asset URL of the newly uploaded avatar.
     *
     * @throws Exception When the image upload fails.
     */
    public function updateProfilePicture(User $user, Request $request): string
    {
        $image = $request->file('avatar');
        // Unique filename so a re-upload never collides with old files.
        $imageName = time().'.'.$image->getClientOriginalExtension();

        // ? Check if there's an existing profile picture
        if ($user->avatar && file_exists(public_path($user->avatar))) {
            Helper::deleteImage(public_path($user->avatar));
        }

        // * Use the Helper class to handle the file upload
        $imagePath = Helper::uploadImage($image, 'profile', $imageName);

        if ($imagePath === null) {
            throw new Exception('Failed to upload image.');
        }

        // ! Update user's avatar with the new image path
        $user->avatar = $imagePath;
        $user->save();

        return asset($imagePath);
    }
}
