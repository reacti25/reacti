<?php

namespace App\Http\Controllers\Api\Auth;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\LoginRequest as ApiLoginRequest;
use App\Http\Requests\Auth\UserRegisterRequest;
use App\Services\AuthService;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

/**
 * Handles the email/password authentication lifecycle for the API.
 *
 * Backs the public `auth` route group: registration with email-OTP
 * verification, OTP resend, JWT login, and logout. This is a thin
 * controller — it validates input, delegates to {@see AuthService}, and
 * shapes the JSON response; all business logic lives in the service.
 */
class AuthenticationController extends Controller
{
    use ApiResponse;

    /**
     * @param  AuthService  $authService  Authentication-lifecycle business logic.
     */
    public function __construct(private readonly AuthService $authService)
    {
        parent::__construct();
    }

    /**
     * Begin registration by emailing a 4-digit OTP.
     *
     * @param  UserRegisterRequest  $request  Validated body: first_name,
     *                                        last_name, email, phone, password.
     * @return \Illuminate\Http\JsonResponse  Success with email + generated
     *                                        username, or 429 / 500 on error.
     */
    public function register(UserRegisterRequest $request)
    {
        try {
            $result = $this->authService->register($request->validated());

            return $this->success($result, 'OTP sent successfully. Please check your email.');
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            Log::error('Registration OTP Error: ' . $e->getMessage());
            return $this->error([], 'Failed to send verification code.', 500);
        }
    }

    /**
     * Re-issue a registration OTP to an in-progress signup.
     *
     * @param  Request  $request  Body: email (the pending registration).
     * @return \Illuminate\Http\JsonResponse  Success with email, 404 if no
     *                                        pending registration, 422/500 on error.
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
            $result = $this->authService->resendRegisterOtp($request->email, $request->first_name);

            return $this->success($result, 'OTP resent successfully.');
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            // Don't leak exception details to the client — log them.
            Log::error('Resend register OTP error: ' . $e->getMessage());
            return $this->error([], 'Something went wrong. Please try again.', 500);
        }
    }

    /**
     * Confirm the registration OTP and create the user account.
     *
     * @param  Request  $request  Body: email, otp (4 digits).
     * @return \Illuminate\Http\JsonResponse  Created user + JWT token, or
     *                                        403 (bad/expired OTP), 404, 422, 500.
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
            $user = $this->authService->verifyEmail($request->email, $request->otp);

            return $this->success($user, 'Email verification successful.');
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            // Don't leak exception details to the client — log them.
            Log::error('Email verify error: ' . $e->getMessage());
            return $this->error([], 'Something went wrong. Please try again.', 500);
        }
    }

    /**
     * Authenticate the user and issue a JWT.
     *
     * @param  ApiLoginRequest  $request  Body: email, password.
     * @return \Illuminate\Http\JsonResponse  User summary + JWT token, or
     *                                        401 (invalid credentials / unverified), 500.
     */
    public function login(ApiLoginRequest $request)
    {
        try {
            $data = $this->authService->login($request->validated());

            return $this->success($data, 'Successfully logged in!', 200);
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            Log::error('Login error: ' . $e->getMessage());
            return $this->error([], 'Something went wrong. Please try again later.', 500);
        }
    }

    /**
     * Log the user out and invalidate their JWT.
     *
     * Optionally accepts a `device_id` body param; when present, the
     * user's Firebase token for that device is also removed.
     *
     * @param  Request  $request  Body: device_id (optional).
     * @return \Illuminate\Http\JsonResponse  Success, 422 (bad device_id), or 500.
     */
    public function logout(Request $request)
    {
        try {
            $user = auth('api')->user();

            // Validate device_id only when the client actually sends it.
            if ($request->has('device_id')) {
                $validator = Validator::make($request->all(), [
                    'device_id' => 'required|string',
                ]);

                if ($validator->fails()) {
                    return $this->error([], $validator->errors()->first(), 422);
                }
            }

            $this->authService->logout(
                $user,
                $request->has('device_id') ? $request->device_id : null
            );

            return $this->success([], 'Successfully logged out.', 200);
        } catch (Exception $e) {
            // Don't leak exception details to the client — log them.
            Log::error('Logout error: ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString(),
            ]);
            return $this->error([], 'Logout failed. Please try again.', 500);
        }
    }
}
