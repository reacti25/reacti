<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Tymon\JWTAuth\Facades\JWTAuth;
use Tymon\JWTAuth\Exceptions\JWTException;
use Symfony\Component\HttpFoundation\Response;
use Tymon\JWTAuth\Exceptions\TokenExpiredException;
use Tymon\JWTAuth\Exceptions\TokenInvalidException;

/**
 * Guards routes that require a valid JWT bearer token.
 *
 * Parses and authenticates the token on each request; expired, invalid, or
 * missing tokens are rejected with the appropriate 401/404 JSON response so
 * controllers can assume an authenticated user.
 */
class AuthCheckMiddleware
{
    /**
     * Handle an incoming request, rejecting it unless a valid JWT resolves to a user.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next  The next handler in the middleware pipeline.
     * @return \Symfony\Component\HttpFoundation\Response  The downstream response, or a JSON error (404/401) when authentication fails.
     */
    public function handle(Request $request, Closure $next)
    {
        try {
            $user = JWTAuth::parseToken()->authenticate();
            if (!$user) {
                return response()->json(['message' => 'User not found'], 404);
            }
        } catch (TokenExpiredException $e) {
            return response()->json(['message' => 'Token expired'], 401);
        } catch (TokenInvalidException $e) {
            return response()->json(['message' => 'Token invalid'], 401);
        } catch (JWTException $e) {
            return response()->json(['message' => 'Authorization token not found'], 401);
        }

        return $next($request);
    }
}
