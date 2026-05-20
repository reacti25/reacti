<?php

namespace App\Services;

use App\Http\Controllers\Api\Auth\SocialLoginController;
use App\Models\User;
use Illuminate\Support\Facades\Auth;
use Laravel\Socialite\Facades\Socialite;

/**
 * Business logic for third-party (social) sign-in.
 *
 * Extracted from {@see SocialLoginController}.
 *
 * Note: the only entry point, {@see googleAuthenticate()}, is currently
 * unreachable — the `social/signin/{provider}` route points at a
 * `socialSignin` action that does not exist. It is kept and refactored
 * verbatim (behaviour unchanged) so the Auth area is consistent; wiring
 * a working route is a separate decision.
 */
class SocialAuthService
{
    /**
     * Authenticate (or register) a user from a Google OAuth token.
     *
     * Socialite resolves the Google profile statelessly; a matching
     * `users` row is found or created and a JWT is issued.
     *
     * @param  string|null  $token  Google OAuth access token from the client.
     * @return array ['id', 'email', 'phone', 'role', 'token'].
     *
     * @throws \Exception When Google verification or account creation fails;
     *                    the controller maps this to a 500 response.
     */
    public function googleAuthenticate(?string $token): array
    {
        // Resolve the Google profile from the access token without a
        // session (stateless) — the mobile client owns the OAuth dance.
        $googleUser = Socialite::driver('google')->stateless()->userFromToken($token);

        // Match on email so an existing password account links to Google;
        // brand-new accounts are created pre-verified.
        $user = User::firstOrCreate(
            ['email' => $googleUser->getEmail()],
            [
                'name' => $googleUser->getName(),
                'google_id' => $googleUser->getId(),
                'avatar' => $googleUser->getAvatar(),
                'password' => bcrypt($googleUser->getId()),
                'is_otp_verified' => 1,
                'is_google_signin' => true,
            ]
        );

        Auth::login($user);

        $token = auth('api')->login($user);

        return [
            'id' => $user->id,
            'email' => $user->email,
            'phone' => $user->phone,
            'role' => $user->role,
            'token' => $token,
        ];
    }
}
