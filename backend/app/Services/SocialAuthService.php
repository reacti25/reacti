<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Helpers\Helper;
use App\Http\Controllers\Api\Auth\SocialLoginController;
use App\Http\Requests\Auth\UserRegisterRequest;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\Auth;
use Laravel\Socialite\Facades\Socialite;

/**
 * Business logic for third-party (social) sign-in.
 *
 * Extracted from {@see SocialLoginController}.
 */
class SocialAuthService
{
    /**
     * Authenticate (or register) a user from a Google OAuth token.
     *
     * Socialite resolves the Google profile statelessly; a matching
     * `users` row is found by email or created pre-verified, and a JWT
     * is issued.
     *
     * @param  string|null  $token  Google OAuth access token from the client.
     * @param  string|null  $dateOfBirth  Birthdate (`Y-m-d`) for the age gate.
     *                                    Required only when this call would
     *                                    create a brand-new account; an
     *                                    existing user signing in again does
     *                                    not resend it.
     * @return array<string, mixed> Keys: id, email, phone, role, token.
     *
     * @throws ApiException 422 when a new account has no acceptable birthdate.
     * @throws \Exception When Google verification or account creation fails;
     *                    the controller maps this to a 500 response.
     */
    public function googleAuthenticate(?string $token, ?string $dateOfBirth = null): array
    {
        // Resolve the Google profile from the access token without a
        // session (stateless) — the mobile client owns the OAuth dance.
        $googleUser = Socialite::driver('google')->stateless()->userFromToken($token);

        // Google returns one display name; split it into the first/last
        // columns the users table actually has (there is no `name`).
        [$firstName, $lastName] = $this->splitName($googleUser->getName());

        // Match on email so an existing password account links to Google.
        $user = User::where('email', $googleUser->getEmail())->first();

        // Brand-new accounts are created pre-verified — but they go through
        // the same age gate as an email signup. This used to be a
        // firstOrCreate, which meant a Google token alone could mint an
        // account without any age check at all (the registration
        // FormRequest never runs on this path). Existing users are NOT
        // asked here: they are covered by the one-time age confirmation
        // (see docs/PLAN-age-gate-2026-08-04.md, phase A4).
        if (! $user) {
            $user = User::create([
                'first_name' => $firstName,
                'last_name' => $lastName,
                'username' => Helper::generateUniqueUsername($firstName, $lastName),
                'google_id' => $googleUser->getId(),
                'avatar' => $googleUser->getAvatar(),
                'date_of_birth' => $this->ageGatedBirthdate($dateOfBirth),
                // The Google id is not a usable password — it just keeps
                // the NOT-NULL-free column populated; social users sign
                // in through Google, never with this value.
                'password' => bcrypt($googleUser->getId()),
                // Social accounts skip the email-OTP step entirely.
                'otp_verified_at' => now(),
                'is_google_signin' => true,
            ]);
        }

        Auth::login($user);

        $jwt = auth('api')->login($user);

        return [
            'id' => $user->id,
            'email' => $user->email,
            'phone' => $user->phone,
            'role' => $user->role,
            'token' => $jwt,
        ];
    }

    /**
     * Validate a birthdate for a new social account, or refuse the signup.
     *
     * Mirrors the rule in {@see UserRegisterRequest} so both ways into an
     * account enforce the same minimum age. Refusing here means the row is
     * never written — there is no half-made account to clean up afterwards.
     *
     * @param  string|null  $dateOfBirth  Birthdate as `Y-m-d`.
     * @return Carbon The accepted birthdate.
     *
     * @throws ApiException 422 when missing, unparseable, or under-age.
     */
    private function ageGatedBirthdate(?string $dateOfBirth): Carbon
    {
        $minAge = (int) config('reacti.min_age');

        if (blank($dateOfBirth)) {
            throw new ApiException('Your date of birth is required.', 422);
        }

        try {
            $dob = Carbon::parse($dateOfBirth);
        } catch (\Exception) {
            throw new ApiException('Please provide a valid date of birth.', 422);
        }

        // A birthday falling today counts as reached, so compare against the
        // cutoff date rather than a whole-year difference.
        if ($dob->startOfDay()->gt(now()->subYears($minAge)->startOfDay())) {
            throw new ApiException("You must be at least {$minAge} to use Reacti.", 422);
        }

        return $dob;
    }

    /**
     * Split a single display name into first and last parts.
     *
     * Everything before the first space is the first name; the rest is
     * the last name. A blank name yields two empty strings.
     *
     * @param  string|null  $name  The provider's display name.
     * @return array{0: string, 1: string} [firstName, lastName].
     */
    private function splitName(?string $name): array
    {
        // explode() always yields at least one element, so $parts[0]
        // exists; $parts[1] is present only when the name has a space.
        $parts = explode(' ', trim((string) $name), 2);

        return [$parts[0], $parts[1] ?? ''];
    }
}
