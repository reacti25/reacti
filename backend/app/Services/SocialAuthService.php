<?php

namespace App\Services;

use App\Helpers\Helper;
use App\Http\Controllers\Api\Auth\SocialLoginController;
use App\Models\User;
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
     * @return array<string, mixed> Keys: id, email, phone, role, token.
     *
     * @throws \Exception When Google verification or account creation fails;
     *                    the controller maps this to a 500 response.
     */
    public function googleAuthenticate(?string $token): array
    {
        // Resolve the Google profile from the access token without a
        // session (stateless) — the mobile client owns the OAuth dance.
        $googleUser = Socialite::driver('google')->stateless()->userFromToken($token);

        // Google returns one display name; split it into the first/last
        // columns the users table actually has (there is no `name`).
        [$firstName, $lastName] = $this->splitName($googleUser->getName());

        // Match on email so an existing password account links to Google;
        // brand-new accounts are created pre-verified.
        $user = User::firstOrCreate(
            ['email' => $googleUser->getEmail()],
            [
                'first_name' => $firstName,
                'last_name' => $lastName,
                'username' => Helper::generateUniqueUsername($firstName, $lastName),
                'google_id' => $googleUser->getId(),
                'avatar' => $googleUser->getAvatar(),
                // The Google id is not a usable password — it just keeps
                // the NOT-NULL-free column populated; social users sign
                // in through Google, never with this value.
                'password' => bcrypt($googleUser->getId()),
                // Social accounts skip the email-OTP step entirely.
                'otp_verified_at' => now(),
                'is_google_signin' => true,
            ]
        );

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
