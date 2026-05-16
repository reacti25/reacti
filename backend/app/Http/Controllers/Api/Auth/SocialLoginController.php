<?php


namespace App\Http\Controllers\Api\Auth;

use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Auth;
use Laravel\Socialite\Facades\Socialite;

/**
 * Handles third-party (social) sign-in for the API.
 *
 * Backs the public social-login routes. Currently exposes Google
 * sign-in via Laravel Socialite; the Apple credentials are loaded in
 * the constructor in anticipation of an Apple sign-in flow.
 */
class SocialLoginController extends Controller
{
    use ApiResponse;

    /** @var string|null Apple "Sign in with Apple" service client id. */
    protected $client_id;

    /** @var string|null Apple key id used to sign the client secret JWT. */
    protected $key_id;

    /** @var string|null Apple developer team id. */
    protected $team_id;

    /** @var string|null Apple private key (.p8 contents) for the secret JWT. */
    protected $private_key;

    /** @var string|null OAuth redirect URL registered with Apple. */
    protected $redirect_url;

    /**
     * Load the Apple OAuth credentials from `config('services.apple')`.
     *
     * @return void
     */
   public function __construct()
    {
        $this->client_id = config('services.apple.client_id');
        $this->key_id = config('services.apple.key_id');
        $this->team_id = config('services.apple.team_id');
        $this->private_key = config('services.apple.private_key');
        $this->redirect_url = config('services.apple.redirect');

        // dd($this->client_id, $this->key_id, $this->team_id, $this->private_key, $this->redirect_url);

    }





    /**
     * Authenticate (or register) a user from a Google OAuth token.
     *
     * The client obtains a Google access token and posts it here;
     * Socialite resolves the Google profile statelessly. A matching
     * `users` row is found or created (new accounts are pre-verified
     * and flagged `is_google_signin`), then a JWT is issued.
     *
     * @param  Request  $request  Body: token (Google OAuth access token)
     * @return \Illuminate\Http\JsonResponse  User summary + JWT token, or
     *                                        500 if Google verification fails
     */
    public function googleAuthentication(Request $request)
    {

       try {

            $token = $request->input('token');

            // Resolve the Google profile from the access token without a
            // session (stateless) — the mobile client owns the OAuth dance.
            $googleUser = Socialite::driver('google')->stateless()->userFromToken($token);


            // Match on email so an existing password account links to
            // Google; brand-new accounts are created pre-verified.
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

            $userData = [
                'id' => $user->id,
                'email' => $user->email,
                'phone' => $user->phone,
                'role' => $user->role,
                'token' => $token,
            ];

            return $this->success($userData, 'Successfully Logged In With Google', 200);
        } catch (\Exception $e) {

            Log::error($e->getMessage());
            return $this->error($e->getMessage(), 'Google Sign In Failed', 500);
        }
    }



}

