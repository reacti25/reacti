<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Helper\Helper;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;

/**
 * Business logic for the authenticated user's own account.
 *
 * Extracted from {@see \App\Http\Controllers\Api\Auth\UserProfileController}.
 * Every method operates on the caller's own `User` model — there is no
 * way to act on another user here.
 */
class ProfileService
{
    /**
     * Reload the user with friend/group counts for the profile screen.
     *
     * Uses `withCount` so the totals come back in a single query, and
     * exposes a combined `total_friends` (requests sent + received).
     *
     * @param  User  $user  The authenticated user.
     * @return User The reloaded user with `*_count` and `total_friends`.
     */
    public function getProfile(User $user): User
    {
        $user = User::withCount([
            'friends as friends_count',
            'friendOf as friend_of_count',
            'groups as groups_count',
        ])->find($user->id);

        $user->total_friends = ($user->friends_count ?? 0) + ($user->friend_of_count ?? 0);

        return $user;
    }

    /**
     * Update the user's profile fields and, optionally, the avatar.
     *
     * When a new avatar is uploaded the previous file is removed first to
     * avoid orphaned images.
     *
     * @param  User  $user  The authenticated user.
     * @param  array  $data  Validated profile fields.
     * @param  UploadedFile|null  $avatar  New avatar image, if supplied.
     * @return User The updated user.
     */
    public function updateProfile(User $user, array $data, ?UploadedFile $avatar): User
    {
        if ($avatar) {
            if ($user->avatar) {
                Helper::deleteImage($user->avatar);
            }
            $data['avatar'] = Helper::uploadImage($avatar, 'profile');
        }

        $user->update($data);

        return $user;
    }

    /**
     * Change the user's username.
     *
     * @param  User  $user  The authenticated user.
     * @param  string  $username  The new (already-unique) username.
     * @return string The saved username.
     */
    public function updateUsername(User $user, string $username): string
    {
        $user->update(['username' => $username]);

        return $user->username;
    }

    /**
     * Change the user's password after verifying the current one.
     *
     * Social-login accounts that never set a password are rejected.
     *
     * @param  User  $user  The authenticated user.
     * @param  string  $currentPassword  The user's current password.
     * @param  string  $newPassword  The new plaintext password.
     *
     * @throws ApiException 400 (social-login account with no password) or
     *                      422 (current password incorrect).
     */
    public function updatePassword(User $user, string $currentPassword, string $newPassword): void
    {
        if (! $user->password) {
            throw new ApiException('You are using social login. Please set up a password first.', 400);
        }

        if (! Hash::check($currentPassword, $user->password)) {
            throw new ApiException('Current password is incorrect.', 422);
        }

        $user->update(['password' => Hash::make($newPassword)]);
    }

    /**
     * Delete the user's account and remove their images from disk.
     *
     * The current JWT is invalidated so the now-deleted user is logged
     * out immediately. The `User` model does not use soft deletes, so the
     * row is removed outright.
     *
     * @param  User  $user  The authenticated user.
     */
    public function deleteProfile(User $user): void
    {
        if ($user->avatar) {
            Helper::deleteImage($user->avatar);
        }

        if ($user->cover) {
            Helper::deleteImage($user->cover);
        }

        $user->delete();

        auth('api')->logout();
    }
}
