<?php

namespace App\Http\Controllers\Api\Auth;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\ResendOtpRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Requests\Auth\VerifyResetOtpRequest;
use App\Services\PasswordResetService;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

/**
 * Drives the forgotten-password / OTP reset flow for the API.
 *
 * Backs the public `auth` password-reset routes: emailing a reset OTP,
 * verifying that OTP in exchange for a short-lived reset token, setting
 * the new password against that token, and resending the OTP. This is a
 * thin controller — it validates input and delegates to
 * {@see PasswordResetService}.
 */
class ResetPasswordController extends Controller
{
    use ApiResponse;

    /**
     * @param  PasswordResetService  $passwordResetService  Reset-flow business logic.
     */
    public function __construct(private readonly PasswordResetService $passwordResetService)
    {
        parent::__construct();
    }

    /**
     * Email a password-reset OTP to a registered, active user.
     *
     * @param  ForgotPasswordRequest  $request  Body: email (must exist in users table).
     * @return JsonResponse Success with email, 404 if no
     *                      active user, 429 throttled, 422/500.
     */
    public function forgotPassword(ForgotPasswordRequest $request)
    {
        try {
            $result = $this->passwordResetService->forgotPassword($request->email);

            return $this->success($result, 'Password reset OTP sent successfully.', 200);
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            Log::error('Forgot Password Error: '.$e->getMessage(), [
                'email' => $request->email ?? 'N/A',
                'trace' => $e->getTraceAsString(),
            ]);

            return $this->error([], 'An error occurred. Please try again later.', 500);
        }
    }

    /**
     * Verify a reset OTP and issue a one-time reset token.
     *
     * @param  VerifyResetOtpRequest  $request  Body: email, otp (4 digits).
     * @return JsonResponse Success with reset token, 404 if
     *                      no user, 400 (expired/invalid OTP), 422/500.
     */
    public function verifyOTP(VerifyResetOtpRequest $request)
    {
        try {
            $token = $this->passwordResetService->verifyOtp($request->email, $request->otp);

            // Bespoke envelope (not the ApiResponse shape) — the client
            // reads `token` off the top level here.
            return response()->json([
                'status' => true,
                'message' => 'OTP verified successfully.',
                'code' => 200,
                'token' => $token,
            ]);
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            // Don't leak exception details to the client — log them.
            Log::error('Verify OTP error: '.$e->getMessage());

            return $this->error([], 'An error occurred. Please try again.', 500);
        }
    }

    /**
     * Set a new password using a verified reset token.
     *
     * @param  ResetPasswordRequest  $request  Body: email, token, password (confirmed).
     * @return JsonResponse Success, 404 if no user,
     *                      401 (invalid/expired token), 422/500.
     */
    public function resetPassword(ResetPasswordRequest $request)
    {
        try {
            $this->passwordResetService->resetPassword(
                $request->email,
                $request->token,
                $request->password
            );

            return $this->success([], 'Password reset successfully.', 200);
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            // Don't leak exception details to the client — log them.
            Log::error('Reset password error: '.$e->getMessage());

            return $this->error([], 'An error occurred. Please try again.', 500);
        }
    }

    /**
     * Re-issue a password-reset OTP to an active user.
     *
     * @param  ResendOtpRequest  $request  Body: email (must exist in users table).
     * @return JsonResponse Success with email, 404 if no
     *                      active user, 429 throttled, 422/500.
     */
    public function resendOtp(ResendOtpRequest $request)
    {
        try {
            $result = $this->passwordResetService->resendOtp($request->email);

            return $this->success($result, 'OTP resent successfully.', 200);
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            Log::error('Resend OTP Error: '.$e->getMessage(), [
                'email' => $request->email ?? 'N/A',
                'trace' => $e->getTraceAsString(),
            ]);

            return $this->error([], 'An error occurred. Please try again later.', 500);
        }
    }
}
