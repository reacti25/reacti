<?php

namespace App\Http\Middleware;

use App\Analytics\Analytics;
use App\Analytics\AnalyticsConsent;
use App\Analytics\AnalyticsEvents;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Emits an `api_request` analytics event (endpoint, method, status, latency)
 * for each API request.
 *
 * Observation only — it returns the response untouched. The emit is
 * fire-and-forget (the transport sends after the response), and the `endpoint`
 * is the **route pattern** (e.g. `api/auth/chat/send/{id}`), never the concrete
 * URL with ids, so no identifiers leak.
 */
class TrackApiMetrics
{
    public function __construct(private readonly Analytics $analytics) {}

    public function handle(Request $request, Closure $next): Response
    {
        $startedAt = microtime(true);
        $response = $next($request);
        $latencyMs = (int) round((microtime(true) - $startedAt) * 1000);

        // Honour the user's opt-out: emit no event carrying their id.
        if (AnalyticsConsent::isOptedOut()) {
            return $response;
        }

        try {
            $this->analytics->track(AnalyticsEvents::API_REQUEST, [
                'endpoint' => $this->routePattern($request),
                'method' => $request->method(),
                'status' => $response->getStatusCode(),
                'latency_ms' => $latencyMs,
            ], $this->userId());
        } catch (\Throwable $e) {
            // Analytics must never affect the response.
        }

        return $response;
    }

    /** The matched route's URI pattern (ids as `{param}`), or the raw path. */
    private function routePattern(Request $request): string
    {
        return $request->route()?->uri() ?? $request->path();
    }

    /** The authenticated API user's id (hashed downstream), or null. */
    private function userId(): ?string
    {
        $id = auth('api')->id();

        return $id !== null ? (string) $id : null;
    }
}
