<?php

namespace App\Http\Controllers\Api\Auth;

use Exception;
use Carbon\Carbon;
use App\Events\UserOnlineEvent;
use App\Models\User;
use App\Helper\Helper;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;
use App\Mail\EmailVerifyMail;
use App\Models\FirebaseTokens;
use Tymon\JWTAuth\Facades\JWTAuth;
use Illuminate\Support\Facades\Log;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Validator;
use App\Http\Requests\Auth\UserRegisterRequest;
use App\Http\Requests\Api\LoginRequest as ApiLoginRequest;

/**
 * Handles the email/password authentication lifecycle for the API.
 *
 * Backs the public `auth` route group: registration with email-OTP
 * verification, OTP resend, JWT login, and logout. Registration data is
 * parked in the cache until the OTP is confirmed, so an unverified email
 * never creates a `users` row. Login/logout also broadcast presence so
 * the chat-list "green dot" updates without polling.
 */
class AuthenticationController extends Controller
{
    use ApiResponse;

    /**
     * Begin registration by emailing a 4-digit OTP.
     *
     * No `users` row is created here — the submitted fields (with the
     * password already hashed) are cached under `register_data_{email}`
     * for 5 minutes and only persisted once the OTP is verified. A
     * 2-minute throttle key prevents OTP spamming.
     *
     * @param  UserRegisterRequest  $request  Validated body: first_name,
     *                                        last_name, email, phone, password
     * @return \Illuminate\Http\JsonResponse  Success with email + generated
     *                                        username, or 429 / 500 on error
     * @throws \Illuminate\Validation\ValidationException  via UserRegisterRequest
     */
    public function register(UserRegisterRequest $request)
    {
        try {
            $email = strtolower(trim($request->email));

            // Rate limiting: block a fresh OTP until the 2-minute
            // cooldown key has expired.
            if (Cache::has("register_otp_{$email}")) {
                $remainingTime = Cache::get("register_otp_time_{$email}") - now()->timestamp;
                if ($remainingTime > 0) {
                    return $this->error([], "Please wait {$remainingTime} seconds before requesting a new OTP.", 429);
                }
            }

            // Generate unique username
            $username = Helper::generateUniqueUsername($request->first_name, $request->last_name);

            // Generate OTP
            $otp = random_int(1000, 9999);
            $otpExpiresAt = now()->addMinutes(5);

            // Cache data (including username)
            $cacheData = [
                'first_name' => $request->first_name,
                'last_name'  => $request->last_name,
                'email'      => $email,
                'phone'      => $request->phone,
                'password'   => Hash::make($request->password),
                'username'   => $username, // Add username
                'otp'        => $otp,
                'otp_expires_at' => $otpExpiresAt,
                'attempts'   => 0,
            ];

            Cache::put("register_otp_{$email}", $otp, 300);
            Cache::put("register_data_{$email}", $cacheData, 300);
            Cache::put("register_otp_time_{$email}", now()->addMinutes(2)->timestamp, 120);

            // Send OTP
            Mail::to($email)->send(new EmailVerifyMail(
                $otp,
                $request->first_name ?? 'User',
                'Verify Your Email Address'
            ));

            return $this->success([
                'email' => $email,
                'expires_in' => '5 minutes',
                'username' => $username,
            ], 'OTP sent successfully. Please check your email.');
        } catch (Exception $e) {
            Log::error('Registration OTP Error: ' . $e->getMessage());
            return $this->error([], 'Failed to send verification code.', 500);
        }
    }

    /**
     * Re-issue a registration OTP to an in-progress signup.
     *
     * Only works while the original `register_data_{email}` cache entry
     * is still alive (within the 5-minute window); otherwise the caller
     * must restart registration.
     *
     * @param  Request  $request  Body: email (the pending registration)
     * @return \Illuminate\Http\JsonResponse  Success with email, 404 if no
     *                                        pending registration, 422/500 on error
     */
    public function resendRegisterOtp(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'nullable|email|max:191',
        ]);

        if ($validator->fails()) {
            return $this->error([], $validator->errors()->first(), 422);
        }

        try {
            $email = $request->email;
            $cachedData = Cache::get("register_data_{$email}");

            if (!$cachedData) {
                return $this->error([], 'No pending registration found. Please register again.', 404);
            }

            // New OTP
            $otp = rand(1000, 9999);
            $otpExpiresAt = Carbon::now()->addMinutes(5);

            // Update cache
            $cachedData['otp'] = $otp;
            $cachedData['otp_expires_at'] = $otpExpiresAt;

            Cache::put("register_otp_{$email}", $otp, 300);
            Cache::put("register_data_{$email}", $cachedData, 300);

            // Resend OTP to email
            Mail::to($email)->send(new EmailVerifyMail($otp, $request->first_name ?? 'User', 'Verify Your Email Address'));

            return $this->success([
                'email' => $email,
                'otp' => $otp,
            ], 'OTP resent successfully.');
        } catch (Exception $e) {
            Log::error($e->getMessage());
            return $this->error([], 'Something went wrong: ' . $e->getMessage(), 500);
        }
    }


    /**
     * Confirm the registration OTP and create the user account.
     *
     * This is the only place a `users` row is created during signup —
     * the cached password is already hashed, so it is stored verbatim.
     * On success all registration cache keys are purged and a JWT is
     * issued so the client is logged in immediately.
     *
     * @param  Request  $request  Body: email, otp (4 digits)
     * @return \Illuminate\Http\JsonResponse  Created user + JWT token, or
     *                                        403 (bad/expired OTP), 404, 422, 500
     */
    public function verifyEmail(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'otp' => 'required|digits:4',
        ]);

        if ($validator->fails()) {
            return $this->error([], $validator->errors()->first(), 422);
        }

        try {
            $email = $request->email;
            $cachedOtp = Cache::get("register_otp_{$email}");
            $cachedData = Cache::get("register_data_{$email}");

            if (!$cachedData || !$cachedOtp) {
                return $this->error([], 'No registration data found or OTP expired. Please register again.', 404);
            }

            if ($cachedOtp != $request->otp) {
                return $this->error([], 'Invalid OTP. Please try again.', 403);
            }

            if (Carbon::parse($cachedData['otp_expires_at'])->isPast()) {
                return $this->error([], 'OTP has expired. Please request a new one.', 403);
            }

            // Create user - password is already hashed in cache, so it is
            // assigned directly without re-hashing.
            $user = User::create([
                'first_name' => $cachedData['first_name'],
                'last_name' => $cachedData['last_name'],
                'username'   => $cachedData['username'],
                'email' => $cachedData['email'],
                'phone' => $cachedData['phone'],
                'password' => $cachedData['password'],
                'otp_verified_at' => now(),
                'status' => 'active',
            ]);

            // Clean cache
            Cache::forget("register_otp_{$email}");
            Cache::forget("register_data_{$email}");
            Cache::forget("register_otp_time_{$email}");  // Don't forget to clean this too

            // Generate token
            $token = JWTAuth::fromUser($user);

            $user->token = $token;
            $user->is_new_user = empty($user->first_name) || empty($user->last_name);

            return $this->success($user, 'Email verification successful.');
        } catch (Exception $e) {
            Log::error($e->getMessage());
            return $this->error([], 'Something went wrong: ' . $e->getMessage(), 500);
        }
    }


    /**
     * Authenticate the user and issue a JWT.
     *
     * Validates against ApiLoginRequest (email + password + optional
     * social_token). Rejects users whose email is not registered, who
     * haven't verified their email (no `otp_verified_at`), whose
     * status is not 'active', or whose password doesn't match.
     *
     * On success:
     *   - bumps `last_activity_at` to now
     *   - issues a JWT via tymon/jwt-auth
     *   - broadcasts `UserOnlineEvent(userId, isOnline=true)` so the
     *     chat-list "green dot" on listening clients flips on without
     *     polling
     *
     * @param  ApiLoginRequest  $request  Body: email, password
     * @return \Illuminate\Http\JsonResponse  User summary + JWT token, or
     *                                        401 (invalid credentials / unverified), 500
     * @throws \Illuminate\Validation\ValidationException  via ApiLoginRequest
     */
    public function login(ApiLoginRequest $request)
    {
        try {
            $validated = $request->validated();
            $email = trim(strtolower($validated['email']));
            $password = $validated['password'];

            // Step 1: Find user by email, active, not deleted
            $user = User::where('email', $email)
                ->where('status', 'active')
                ->whereNull('deleted_at')
                ->first();

            $errors = [];

            // Step 2: Check if user exists
            if (!$user) {
                $errors[] = 'Invalid email.';
            } else {
                // Step 3: Check OTP verification
                if (!$user->otp_verified_at) {
                    return $this->error([], 'Please verify your email before logging in.', 401);
                }

                // Step 4: Check password
                if (!Hash::check($password, $user->password)) {
                    $errors[] = 'Invalid password.';
                }
            }

            // Step 5: If any error, return appropriate message
            if (!empty($errors)) {
                $message = count($errors) === 1
                    ? $errors[0]
                    : 'Invalid email or password.';

                return $this->error([], $message, 401);
            }

            // Step 6: Login successful
            auth('api')->login($user); // or use attempt if needed, but since we checked, direct login

            // Update last activity
            $user->update(['last_activity_at' => now()]);
            $user->makeHidden(['password', 'otp', 'reset_password_token']);

            // Tell the rest of the app this user is online so chat clients
            // can flip the green-dot presence indicator without polling.
            broadcast(new UserOnlineEvent($user->id, true));

            $data = [
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

            return $this->success($data, 'Successfully logged in!', 200);
        } catch (Exception $e) {
            Log::error('Login error: ' . $e->getMessage());
            return $this->error([], 'Something went wrong. Please try again later.', 500);
        }
    }


    /**
     * Log the user out and invalidate their JWT.
     *
     * Optionally accepts a `device_id` body param. When present, the
     * user's Firebase token for that device is also removed (so the
     * server stops trying to push notifications to a now-signed-out
     * client).
     *
     * Broadcasts `UserOnlineEvent(userId, isOnline=false)` so the
     * chat-list "green dot" on listening clients flips off. The
     * broadcast fires BEFORE `auth('api')->logout()` because once
     * JWT::invalidate() runs, `$user` becomes unreachable.
     *
     * @param  Request  $request  Body: device_id (optional)
     * @return \Illuminate\Http\JsonResponse  Success, 422 (bad device_id), or 500
     */
    public function logout(Request $request)
    {
        try {
            // First get user before logout
            $user = auth('api')->user();

            // Log koro debugging er jonno
            Log::info('Logout attempt', [
                'user_id' => $user ? $user->id : null,
                'device_id' => $request->device_id ?? null
            ]);

            // Validate device_id - optional banao (jodi frontend theke na ashe)
            if ($request->has('device_id')) {
                $validator = Validator::make($request->all(), [
                    'device_id' => 'required|string'
                ]);

                if ($validator->fails()) {
                    return $this->error([], $validator->errors()->first(), 422);
                }

                // Firebase token delete - only if user exists
                if ($user) {
                    $deleted = FirebaseTokens::where('user_id', $user->id)
                        ->where('device_id', $request->device_id)
                        ->delete();

                    Log::info('Token deleted', ['count' => $deleted]);
                }
            }

            // Tell other clients this user is going offline before tearing
            // down the JWT — once auth('api')->logout() runs, $user is gone.
            if ($user) {
                broadcast(new UserOnlineEvent($user->id, false));
            }

            // Logout
            auth('api')->logout();

            return $this->success([], 'Successfully logged out.', 200);
        } catch (Exception $e) {
            Log::error('Logout error: ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString()
            ]);
            return $this->error([], 'Logout failed: ' . $e->getMessage(), 500);
        }
    }
}
