<?php

namespace App\Services;

use App\Events\UserOnlineEvent;
use App\Exceptions\ApiException;
use App\Helpers\Helper;
use App\Http\Controllers\Api\Auth\AuthenticationController;
use App\Mail\EmailVerifyMail;
use App\Models\FirebaseTokens;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Tymon\JWTAuth\Facades\JWTAuth;

/**
 * Business logic for the email/password authentication lifecycle.
 *
 * Extracted from {@see AuthenticationController}
 * so the controller only validates input and shapes responses. Expected
 * business-rule failures are raised as {@see ApiException} with the same
 * status code the controller previously returned inline.
 */
class AuthService
{
    /**
     * Begin registration: cache the pending account and email an OTP.
     *
     * No `users` row is created — the submitted fields (password already
     * hashed) are parked in the cache under `register_data_{email}` for
     * 5 minutes. A 2-minute throttle key blocks OTP spamming.
     *
     * @param  array  $data  Validated body: first_name, last_name, email,
     *                       phone, password.
     * @return array ['email', 'expires_in', 'username'].
     *
     * @throws ApiException 429 while the OTP cooldown is still active.
     */
    public function register(array $data): array
    {
        $email = strtolower(trim($data['email']));

        // Refuse a fresh OTP until the 2-minute cooldown key has expired.
        if (Cache::has("register_otp_{$email}")) {
            $remainingTime = Cache::get("register_otp_time_{$email}") - now()->timestamp;
            if ($remainingTime > 0) {
                throw new ApiException("Please wait {$remainingTime} seconds before requesting a new OTP.", 429);
            }
        }

        $username = Helper::generateUniqueUsername($data['first_name'], $data['last_name']);

        $otp = random_int(1000, 9999);
        $otpExpiresAt = now()->addMinutes(5);

        $cacheData = [
            'first_name' => $data['first_name'],
            // last_name and phone are nullable in UserRegisterRequest, so
            // they may be absent from the validated payload.
            'last_name' => $data['last_name'] ?? null,
            'email' => $email,
            'phone' => $data['phone'] ?? null,
            'password' => Hash::make($data['password']),
            'username' => $username,
            'otp' => $otp,
            'otp_expires_at' => $otpExpiresAt,
            'attempts' => 0,
        ];

        Cache::put("register_otp_{$email}", $otp, 300);
        Cache::put("register_data_{$email}", $cacheData, 300);
        Cache::put("register_otp_time_{$email}", now()->addMinutes(2)->timestamp, 120);

        Mail::to($email)->send(new EmailVerifyMail(
            $otp,
            $data['first_name'] ?? 'User',
            'Verify Your Email Address'
        ));

        return [
            'email' => $email,
            'expires_in' => '5 minutes',
            'username' => $username,
        ];
    }

    /**
     * Re-issue a registration OTP for an in-progress signup.
     *
     * Only works while the `register_data_{email}` cache entry is alive.
     *
     * @param  string|null  $email  Email of the pending registration.
     * @param  string|null  $firstName  Name used in the email greeting.
     * @return array ['email', 'otp'].
     *
     * @throws ApiException 404 when there is no pending registration.
     */
    public function resendRegisterOtp(?string $email, ?string $firstName): array
    {
        $cachedData = Cache::get("register_data_{$email}");

        if (! $cachedData) {
            throw new ApiException('No pending registration found. Please register again.', 404);
        }

        // random_int is the CSPRNG; rand() is not cryptographically
        // secure and must not generate OTPs.
        $otp = random_int(1000, 9999);
        $otpExpiresAt = Carbon::now()->addMinutes(5);

        $cachedData['otp'] = $otp;
        $cachedData['otp_expires_at'] = $otpExpiresAt;

        Cache::put("register_otp_{$email}", $otp, 300);
        Cache::put("register_data_{$email}", $cachedData, 300);

        Mail::to($email)->send(new EmailVerifyMail($otp, $firstName ?? 'User', 'Verify Your Email Address'));

        // The OTP is delivered only by email — never returned in the
        // response body.
        return [
            'email' => $email,
        ];
    }

    /**
     * Confirm the registration OTP and create the user account.
     *
     * The only place a `users` row is created during signup. The cached
     * password is already hashed, so it is stored verbatim. On success
     * the registration cache keys are purged and a JWT is attached.
     *
     * @param  string  $email  Email of the pending registration.
     * @param  string  $otp  The 4-digit OTP submitted by the client.
     * @return User The created user, with `token` and `is_new_user` set.
     *
     * @throws ApiException 404 (no pending data) or 403 (wrong/expired OTP).
     */
    public function verifyEmail(string $email, string $otp): User
    {
        $cachedOtp = Cache::get("register_otp_{$email}");
        $cachedData = Cache::get("register_data_{$email}");

        if (! $cachedData || ! $cachedOtp) {
            throw new ApiException('No registration data found or OTP expired. Please register again.', 404);
        }

        if ($cachedOtp != $otp) {
            throw new ApiException('Invalid OTP. Please try again.', 403);
        }

        if (Carbon::parse($cachedData['otp_expires_at'])->isPast()) {
            throw new ApiException('OTP has expired. Please request a new one.', 403);
        }

        // Password is already hashed in the cache, so it is assigned directly.
        $user = User::create([
            'first_name' => $cachedData['first_name'],
            'last_name' => $cachedData['last_name'],
            'username' => $cachedData['username'],
            'email' => $cachedData['email'],
            'phone' => $cachedData['phone'],
            'password' => $cachedData['password'],
            'otp_verified_at' => now(),
            'status' => 'active',
        ]);

        Cache::forget("register_otp_{$email}");
        Cache::forget("register_data_{$email}");
        Cache::forget("register_otp_time_{$email}");

        $token = JWTAuth::fromUser($user);

        $user->token = $token;
        $user->is_new_user = empty($user->first_name) || empty($user->last_name);

        return $user;
    }

    /**
     * Authenticate a user and issue a JWT.
     *
     * Rejects unknown/inactive emails, unverified accounts, and wrong
     * passwords. On success the user is logged into the `api` guard,
     * `last_activity_at` is bumped, and `UserOnlineEvent` is broadcast.
     *
     * @param  array  $credentials  Validated body: email, password.
     * @return array Login payload: id, names, username, email, role,
     *               avatar, token, last_activity_at.
     *
     * @throws ApiException 401 for unverified email or invalid credentials.
     */
    public function login(array $credentials): array
    {
        $email = trim(strtolower($credentials['email']));
        $password = $credentials['password'];

        $user = User::where('email', $email)
            ->where('status', 'active')
            ->whereNull('deleted_at')
            ->first();

        $errors = [];

        if (! $user) {
            $errors[] = 'Invalid email.';
        } else {
            if (! $user->otp_verified_at) {
                throw new ApiException('Please verify your email before logging in.', 401);
            }

            if (! Hash::check($password, $user->password)) {
                $errors[] = 'Invalid password.';
            }
        }

        if (! empty($errors)) {
            $message = count($errors) === 1
                ? $errors[0]
                : 'Invalid email or password.';

            throw new ApiException($message, 401);
        }

        auth('api')->login($user);

        $user->update(['last_activity_at' => now()]);
        $user->makeHidden(['password', 'otp', 'reset_password_token']);

        // Tell listening clients this user is online (chat-list green dot).
        broadcast(new UserOnlineEvent($user->id, true));

        return [
            'id' => $user->id,
            'first_name' => $user->first_name,
            'last_name' => $user->last_name,
            'username' => $user->username,
            'email' => $user->email,
            'role' => $user->role,
            'avatar' => $user->avatar,
            'token' => auth('api')->tokenById($user->id),
            'last_activity_at' => $user->last_activity_at,
        ];
    }

    /**
     * Log the user out and invalidate their JWT.
     *
     * When a device id is supplied, that device's Firebase push token is
     * also removed. `UserOnlineEvent(false)` is broadcast before the JWT
     * is torn down, while the user is still resolvable.
     *
     * @param  User|null  $user  The authenticated user, if resolvable.
     * @param  string|null  $deviceId  Device whose Firebase token to drop.
     */
    public function logout(?User $user, ?string $deviceId): void
    {
        Log::info('Logout attempt', [
            'user_id' => $user?->id,
            'device_id' => $deviceId,
        ]);

        // Drop the Firebase token so the server stops pushing to a
        // now-signed-out device.
        if ($deviceId !== null && $user) {
            $deleted = FirebaseTokens::where('user_id', $user->id)
                ->where('device_id', $deviceId)
                ->delete();

            Log::info('Token deleted', ['count' => $deleted]);
        }

        // Broadcast offline before tearing down the JWT — once
        // auth('api')->logout() runs, $user is no longer reachable.
        if ($user) {
            broadcast(new UserOnlineEvent($user->id, false));
        }

        auth('api')->logout();
    }
}
