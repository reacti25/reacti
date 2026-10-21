<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Says which origin answered: `X-Reacti-Origin: hostinger` today, `aws`
 * after the move. Cloudflare sits in front of both, so during the cutover
 * this header is the only way a check can tell where a response came from
 * (AWS plan, step 1.7). Value from SERVED_BY.
 */
class AddServedByHeader
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);
        $response->headers->set('X-Reacti-Origin', config('app.served_by'));

        return $response;
    }
}
