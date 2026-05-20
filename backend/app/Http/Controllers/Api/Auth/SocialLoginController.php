<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Services\SocialAuthService;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Handles third-party (social) sign-in for the API.
 *
 * Thin controller delegating to {@see SocialAuthService}.
 *
 * Note: {@see googleAuthentication()} is currently unreachable — the
 * `social/signin/{provider}` route points at a `socialSignin` action
 * that does not exist on this controller. The method is kept verbatim
 * (behaviour unchanged); wiring a working route is a separate decision.
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
     * Authenticate (or register) a user from a Google OAuth token.
     *
     * @param  Request  $request  Body: token (Google OAuth access token).
     * @return \Illuminate\Http\JsonResponse  User summary + JWT token, or
     *                                        500 if Google verification fails.
     */
    public function googleAuthentication(Request $request)
    {
        try {
            $userData = $this->socialAuthService->googleAuthenticate($request->input('token'));

            return $this->success($userData, 'Successfully Logged In With Google', 200);
        } catch (Exception $e) {
            // Don't leak exception details to the client — log them.
            Log::error('Google sign-in error: ' . $e->getMessage());
            return $this->error([], 'Google Sign In Failed', 500);
        }
    }
}
