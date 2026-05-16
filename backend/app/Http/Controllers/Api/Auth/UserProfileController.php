<?php

namespace App\Http\Controllers\Api\Auth;

use Exception;
use App\Helper\Helper;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

/**
 * Manages the authenticated user's own account and profile.
 *
 * Backs the authenticated `auth` profile routes: viewing the profile,
 * updating profile fields / avatar, changing username and password, and
 * soft-deleting the account. Every action operates on `auth('api')->
 * user()` — there is no way to act on another user here.
 */
class UserProfileController extends Controller
{
    use ApiResponse;


    /**
     * Return the authenticated user's profile with friend/group counts.
     *
     * Reloads the user with `withCount` so friends, friend-of, and group
     * totals are computed in a single query, and exposes a combined
     * `total_friends` (requests sent + received).
     *
     * @return \Illuminate\Http\JsonResponse  UserResource payload, or
     *                                        401 if unauthenticated, 500 on error
     */
    public function profile()
    {
        try {
            $user = auth('api')->user();

            if (!$user) {
                return $this->error([], 'User not found.', 401);
            }

            // Efficient: Load with count
            $user = User::withCount([
                'friends as friends_count',
                'friendOf as friend_of_count',
                'groups as groups_count'
            ])
                ->find($user->id);

            // Total friends = sent + received
            $user->total_friends = ($user->friends_count ?? 0) + ($user->friend_of_count ?? 0);

            return $this->success(new UserResource($user), 'User Profile Retrieved Successfully', 200);
        } catch (Exception $e) {
            return $this->error([], $e->getMessage(), 500);
        }
    }

    /**
     * Update the authenticated user's profile fields and/or avatar.
     *
     * All fields are optional, so the client can patch one at a time.
     * When a new avatar is uploaded the previous file is removed from
     * disk first to avoid orphaned images.
     *
     * @param  Request  $request  Body: first_name, last_name, avatar
     *                            (image), bio, phone — all nullable
     * @return \Illuminate\Http\JsonResponse  Updated UserResource, or
     *                                        422 on validation failure, 500 on error
     */
    public function updateProfile(Request $request)
    {
        try {
            $user = auth('api')->user();

            $validator = Validator::make($request->all(), [
                'first_name' => ['nullable', 'string', 'max:50'],
                'last_name' => ['nullable', 'string', 'max:50'],
                'avatar' => ['nullable', 'image'],
                'bio' => ['nullable', 'string', 'max:100'],
                'phone' => ['nullable', 'string', 'max:20', 'unique:users,phone,' . $user->id],
            ]);

            if ($validator->fails()) {
                return $this->error([], $validator->errors()->first(), 422);
            }

            $data = $validator->validated();

            // Handle avatar upload
            if ($request->hasFile('avatar')) {
                if ($user->avatar) {
                    Helper::deleteImage($user->avatar);
                }
                $avatarPath = Helper::uploadImage($request->file('avatar'), 'profile');
                $data['avatar'] = $avatarPath;
            }

            // Update user
            $user->update($data);

            return $this->success(new UserResource($user), 'Profile updated successfully.', 200);
        } catch (Exception $e) {
            Log::error('Profile Update Error: ' . $e->getMessage(), [
                'user_id' => auth('api')->id(),
                'trace' => $e->getTraceAsString()
            ]);
            return $this->error([], 'Failed to update profile.', 500);
        }
    }

    /**
     * Change the authenticated user's username.
     *
     * The new username must be unique across users (the current user's
     * own row is excluded from the uniqueness check).
     *
     * @param  Request  $request  Body: username (required, unique)
     * @return \Illuminate\Http\JsonResponse  The saved username string, or
     *                                        422 on validation failure, 500 on error
     */
    public function updateUsername(Request $request){
        try {
            $user = auth('api')->user();

            $validator = Validator::make($request->all(), [
                'username' => ['required', 'string', 'max:50', 'unique:users,username,' . $user->id],
            ]);

            if ($validator->fails()) {
                return $this->error([], $validator->errors()->first(), 422);
            }

            $user->update($validator->validated());
            $username = $user->username;

            return $this->success($username, 'Username updated successfully.', 200);
        } catch (Exception $e) {
            Log::error('Username Update Error: ' . $e->getMessage(), [
                'user_id' => auth('api')->id(),
                'trace' => $e->getTraceAsString()
            ]);
            return $this->error([], 'Failed to update username.', 500);
        }
    }

    /**
     * Change the authenticated user's password.
     *
     * Requires the correct current password. Social-login accounts that
     * never set a password are rejected with guidance to set one first.
     *
     * @param  Request  $request  Body: current_password, password (confirmed)
     * @return \Illuminate\Http\JsonResponse  Success, 400 (social-login,
     *                                        no password), 422 (wrong/invalid), 500
     */
    public function updatePassword(Request $request)
    {
        try {
            $validator = Validator::make($request->all(), [
                'current_password' => ['required', 'string', 'min:8'],
                'password' => ['required', 'string', 'min:8', 'confirmed'],
            ]);

            if ($validator->fails()) {
                return $this->error([], $validator->errors()->first(), 422);
            }

            $user = auth('api')->user();

            // Check if user has password (for social login users)
            if (!$user->password) {
                return $this->error([], 'You are using social login. Please set up a password first.', 400);
            }

            // Verify current password
            if (!Hash::check($request->current_password, $user->password)) {
                return $this->error([], 'Current password is incorrect.', 422);
            }

            // Update password
            $user->update(['password' => Hash::make($request->password)]);

            return $this->success([], 'Password updated successfully.', 200);
        } catch (Exception $e) {
            Log::error('Password Update Error: ' . $e->getMessage(), [
                'user_id' => auth('api')->id(),
            ]);
            return $this->error([], 'Failed to update password.', 500);
        }
    }

    /**
     * Soft-delete the authenticated user's account.
     *
     * Removes the avatar and cover images from disk, soft-deletes the
     * `users` row, and invalidates the current JWT so the now-deleted
     * user is immediately logged out.
     *
     * @param  Request  $request  Unused; present for route signature consistency.
     * @return \Illuminate\Http\JsonResponse  Success, or 500 on error
     */
    public function deleteProfile(Request $request)
    {
        try {
            $user = auth('api')->user();

            // Delete images
            if ($user->avatar) {
                Helper::deleteImage($user->avatar);
            }

            if ($user->cover) {
                Helper::deleteImage($user->cover);
            }

            // Soft delete user
            $user->delete();

            // Logout and invalidate token
            auth('api')->logout();

            return $this->success([], 'Profile deleted successfully.', 200);
        } catch (Exception $e) {
            Log::error('Profile Delete Error: ' . $e->getMessage(), [
                'user_id' => auth('api')->id(),
                'trace' => $e->getTraceAsString()
            ]);
            return $this->error([], 'Failed to delete profile.', 500);
        }
    }
}
