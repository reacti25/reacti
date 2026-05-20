<?php

namespace App\Http\Controllers\Api\Auth;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Services\ProfileService;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

/**
 * Manages the authenticated user's own account and profile.
 *
 * Backs the authenticated `auth` profile routes: viewing the profile,
 * updating profile fields / avatar, changing username and password, and
 * deleting the account. This is a thin controller — it validates input
 * and delegates to {@see ProfileService}. Every action operates on
 * `auth('api')->user()`; there is no way to act on another user here.
 */
class UserProfileController extends Controller
{
    use ApiResponse;

    /**
     * @param  ProfileService  $profileService  Profile/account business logic.
     */
    public function __construct(private readonly ProfileService $profileService)
    {
        parent::__construct();
    }

    /**
     * Return the authenticated user's profile with friend/group counts.
     *
     * @return \Illuminate\Http\JsonResponse  UserResource payload, or
     *                                        401 if unauthenticated, 500 on error.
     */
    public function profile()
    {
        try {
            $user = auth('api')->user();

            if (!$user) {
                return $this->error([], 'User not found.', 401);
            }

            $user = $this->profileService->getProfile($user);

            return $this->success(new UserResource($user), 'User Profile Retrieved Successfully', 200);
        } catch (Exception $e) {
            // Don't leak exception details to the client — log them.
            Log::error('Get profile error: ' . $e->getMessage());
            return $this->error([], 'Failed to retrieve profile.', 500);
        }
    }

    /**
     * Update the authenticated user's profile fields and/or avatar.
     *
     * @param  Request  $request  Body: first_name, last_name, avatar
     *                            (image), bio, phone — all nullable.
     * @return \Illuminate\Http\JsonResponse  Updated UserResource, or
     *                                        422 on validation failure, 500 on error.
     */
    public function updateProfile(Request $request)
    {
        try {
            $user = auth('api')->user();

            $validator = Validator::make($request->all(), [
                'first_name' => ['nullable', 'string', 'max:50'],
                'last_name'  => ['nullable', 'string', 'max:50'],
                'avatar'     => ['nullable', 'image'],
                'bio'        => ['nullable', 'string', 'max:100'],
                'phone'      => ['nullable', 'string', 'max:20', 'unique:users,phone,' . $user->id],
            ]);

            if ($validator->fails()) {
                return $this->error([], $validator->errors()->first(), 422);
            }

            $user = $this->profileService->updateProfile(
                $user,
                $validator->validated(),
                $request->file('avatar')
            );

            return $this->success(new UserResource($user), 'Profile updated successfully.', 200);
        } catch (Exception $e) {
            Log::error('Profile Update Error: ' . $e->getMessage(), [
                'user_id' => auth('api')->id(),
                'trace'   => $e->getTraceAsString(),
            ]);
            return $this->error([], 'Failed to update profile.', 500);
        }
    }

    /**
     * Change the authenticated user's username.
     *
     * @param  Request  $request  Body: username (required, unique).
     * @return \Illuminate\Http\JsonResponse  The saved username string, or
     *                                        422 on validation failure, 500 on error.
     */
    public function updateUsername(Request $request)
    {
        try {
            $user = auth('api')->user();

            $validator = Validator::make($request->all(), [
                'username' => ['required', 'string', 'max:50', 'unique:users,username,' . $user->id],
            ]);

            if ($validator->fails()) {
                return $this->error([], $validator->errors()->first(), 422);
            }

            $username = $this->profileService->updateUsername($user, $request->username);

            return $this->success($username, 'Username updated successfully.', 200);
        } catch (Exception $e) {
            Log::error('Username Update Error: ' . $e->getMessage(), [
                'user_id' => auth('api')->id(),
                'trace'   => $e->getTraceAsString(),
            ]);
            return $this->error([], 'Failed to update username.', 500);
        }
    }

    /**
     * Change the authenticated user's password.
     *
     * @param  Request  $request  Body: current_password, password (confirmed).
     * @return \Illuminate\Http\JsonResponse  Success, 400 (social-login,
     *                                        no password), 422 (wrong/invalid), 500.
     */
    public function updatePassword(Request $request)
    {
        try {
            $validator = Validator::make($request->all(), [
                'current_password' => ['required', 'string', 'min:8'],
                'password'         => ['required', 'string', 'min:8', 'confirmed'],
            ]);

            if ($validator->fails()) {
                return $this->error([], $validator->errors()->first(), 422);
            }

            $user = auth('api')->user();

            $this->profileService->updatePassword(
                $user,
                $request->current_password,
                $request->password
            );

            return $this->success([], 'Password updated successfully.', 200);
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            Log::error('Password Update Error: ' . $e->getMessage(), [
                'user_id' => auth('api')->id(),
            ]);
            return $this->error([], 'Failed to update password.', 500);
        }
    }

    /**
     * Delete the authenticated user's account.
     *
     * @param  Request  $request  Unused; present for route signature consistency.
     * @return \Illuminate\Http\JsonResponse  Success, or 500 on error.
     */
    public function deleteProfile(Request $request)
    {
        try {
            $user = auth('api')->user();

            $this->profileService->deleteProfile($user);

            return $this->success([], 'Profile deleted successfully.', 200);
        } catch (Exception $e) {
            Log::error('Profile Delete Error: ' . $e->getMessage(), [
                'user_id' => auth('api')->id(),
                'trace'   => $e->getTraceAsString(),
            ]);
            return $this->error([], 'Failed to delete profile.', 500);
        }
    }
}
