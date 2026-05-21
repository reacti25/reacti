<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Services\SocialAuthService;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Handles third-party (social) sign-in for the API.
 *
 * Thin controller delegating to {@see SocialAuthService}. Reached via
 * `POST /api/social/signin/{provider}` — see the guest group in
 * routes/api.php, where `{provider}` is constrained to the supported
 * set.
 */
class SocialLoginController extends Controller
{
    use ApiResponse;

    /**
     * @param  SocialAuthService  $socialAuthService  Social sign-in business logic.
     */
    public function __construct(private readonly SocialAuthService $socialAuthService)
    {
        parent::__construct();
    }

    /**
     * Authenticate (or register) a user via a social provider.
     *
     * Dispatches on the `{provider}` route segment. Only `google` is
     * implemented; any other provider returns 422 so the route can be
     * widened the moment a new provider's flow lands.
     *
     * @param  Request  $request  Body: token (the provider's OAuth token).
     * @param  string  $provider  Route segment: the social provider.
     * @return JsonResponse User summary + JWT token; 422 for an
     *                      unsupported provider; 500 if verification fails.
     */
    public function socialSignin(Request $request, string $provider): JsonResponse
    {
        if ($provider !== 'google') {
            return $this->error([], "Unsupported social provider: {$provider}.", 422);
        }

        try {
            $userData = $this->socialAuthService->googleAuthenticate($request->input('token'));

            return $this->success($userData, 'Successfully Logged In With Google', 200);
        } catch (Exception $e) {
            // Don't leak exception details to the client — log them.
            Log::error('Google sign-in error: '.$e->getMessage());

            return $this->error([], 'Google Sign In Failed', 500);
        }
    }
}
