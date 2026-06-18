<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Http\Controllers\Api\Auth\ResetPasswordController;
use App\Mail\OtpMail;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

/**
 * Business logic for the forgotten-password / OTP reset flow.
 *
 * Extracted from {@see ResetPasswordController}.
 * Unlike registration, OTP state lives on the `users` row itself
 * (`otp`, `otp_expires_at`, `reset_password_token`,
 * `reset_password_token_expire_at`).
 */
class PasswordResetService
{
    /**
     * Email a password-reset OTP to a registered, active user.
     *
     * Rate-limited: a new OTP is refused while the previous one still has
     * more than ~4 minutes of life left.
     *
     * @param  string  $email  Email address requesting the reset.
     * @return array ['email', 'expires_in', 'otp'].
     *
     * @throws ApiException 404 (no active user) or 429 (throttled).
     */
    public function forgotPassword(string $email): array
    {
        $email = strtolower(trim($email));

        $user = User::where('email', $email)
            ->where('status', 'active')
            ->first();

        if (! $user) {
            throw new ApiException('User not found.', 404);
        }

        // Refuse a new OTP while the previous one still has >4 min left.
        if ($user->otp_expires_at && Carbon::parse($user->otp_expires_at)->isFuture()) {
            $remainingTime = Carbon::parse($user->otp_expires_at)->diffInSeconds(now());
            if ($remainingTime > 240) {
                throw new ApiException('Please wait before requesting a new OTP.', 429);
            }
        }

        return $this->issueAndSendResetOtp($user);
    }

    /**
     * Verify a reset OTP and issue a one-time reset token.
     *
     * On success the OTP is cleared and a random 60-char
     * `reset_password_token` (valid 5 minutes) is stored.
     *
     * @param  string  $email  Email address being verified.
     * @param  string  $otp  The 4-digit OTP submitted by the client.
     * @return string The reset token the client must present to reset.
     *
     * @throws ApiException 404 (no user) or 400 (expired/invalid OTP).
     */
    public function verifyOtp(string $email, string $otp): string
    {
        $user = User::where('email', $email)->first();

        if (! $user) {
            throw new ApiException('User not found', 404);
        }

        if (Carbon::parse($user->otp_expires_at)->isPast()) {
            throw new ApiException('OTP has expired', 400);
        }

        if ($user->otp !== $otp) {
            throw new ApiException('Invalid OTP', 400);
        }

        $token = Str::random(60);

        $user->update([
            'otp' => null,
            'otp_expires_at' => null,
            'reset_password_token' => $token,
            'reset_password_token_expire_at' => Carbon::now()->addMinutes(5),
        ]);

        return $token;
    }

    /**
     * Set a new password using a verified reset token.
     *
     * The token is consumed (nulled) on success so it cannot be replayed.
     *
     * @param  string  $email  Email address of the account.
     * @param  string  $token  The reset token issued by {@see verifyOtp()}.
     * @param  string  $password  The new plaintext password.
     *
     * @throws ApiException 404 (no user) or 401 (invalid/expired token).
     */
    public function resetPassword(string $email, string $token, string $password): void
    {
        $user = User::where('email', $email)->first();

        if (! $user) {
            throw new ApiException('User not found', 404);
        }

        if (
            empty($user->reset_password_token) ||
            $user->reset_password_token !== $token ||
            Carbon::now()->gt($user->reset_password_token_expire_at)
        ) {
            Log::error('Invalid token or token expired', [
                'expires_at' => $user->reset_password_token_expire_at,
            ]);
            throw new ApiException('Invalid token or token expired', 401);
        }

        $user->update([
            'password' => Hash::make($password),
            'reset_password_token' => null,
            'reset_password_token_expire_at' => null,
        ]);
    }

    /**
     * Re-issue a password-reset OTP to an active user.
     *
     * Throttled to one OTP per 60 seconds.
     *
     * @param  string  $email  Email address requesting a new OTP.
     * @return array ['email', 'expires_in', 'otp'].
     *
     * @throws ApiException 404 (no active user) or 429 (throttled).
     */
    public function resendOtp(string $email): array
    {
        $email = strtolower(trim($email));

        $user = User::where('email', $email)
            ->where('status', 'active')
            ->first();

        if (! $user) {
            throw new ApiException('User not found.', 404);
        }

        // One OTP per 60s, derived from the stored expiry minus its 5-min life.
        if ($user->otp_expires_at) {
            $lastSent = Carbon::parse($user->otp_expires_at)->subMinutes(5);
            $secondsSinceLast = (int) $lastSent->diffInSeconds(now());

            if ($secondsSinceLast < 60) {
                $secondsLeft = 60 - $secondsSinceLast;
                throw new ApiException("Please wait {$secondsLeft} seconds before requesting a new OTP.", 429);
            }
        }

        return $this->issueAndSendResetOtp($user);
    }

    /**
     * Generate a fresh reset OTP, persist it (5-minute expiry), email it, and
     * return the public response payload.
     *
     * Shared by {@see forgotPassword()} and {@see resendOtp()}; their differing
     * rate-limit checks run before this is called. The OTP is delivered only by
     * email and is never returned in the response body.
     *
     * @param  User  $user  The account to issue the reset OTP for.
     * @return array{email: string, expires_in: string}
     */
    private function issueAndSendResetOtp(User $user): array
    {
        $otp = random_int(1000, 9999);

        $user->update([
            'otp' => $otp,
            'otp_expires_at' => Carbon::now()->addMinutes(5),
        ]);

        Mail::to($user->email)->send(new OtpMail($otp, $user));

        return [
            'email' => $user->email,
            'expires_in' => '5 minutes',
        ];
    }
}
