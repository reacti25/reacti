<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Restricts a route to authenticated users whose role is `admin`.
 *
 * Gates the admin-only API surface: any non-admin (or unauthenticated)
 * caller receives a 403 JSON response instead of reaching the controller.
 */
class AdminMiddleware
{
    /**
     * Handle an incoming request, allowing only admin users through.
     *
     * @param  Request  $request  The incoming HTTP request.
     * @param  Closure  $next  The next handler in the middleware pipeline.
     * @return Response The downstream response, or a 403 JSON body when the user is not an admin.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = auth()->user();

        if ($user && $user->role === 'admin') {
            return $next($request);
        }

        return response()->json(['status' => false, 'message' => 'Unauthorized access. Role should be admin.', 'code' => 403], 403);
    }
}
