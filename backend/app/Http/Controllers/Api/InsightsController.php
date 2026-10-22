<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\InsightsService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Feeds the Reacti Insights dashboard build (GitHub Actions) with anonymous
 * per-person journeys from the database. Not for the app: it is guarded by a
 * shared secret, not a user login.
 */
class InsightsController extends Controller
{
    use ApiResponse;

    /**
     * @param  InsightsService  $insights  Builds the journeys.
     */
    public function __construct(private readonly InsightsService $insights)
    {
        parent::__construct();
    }

    /**
     * Return {@see InsightsService::journeys()} to a caller holding the token.
     *
     * 404 while `INSIGHTS_TOKEN` is unset, so the route does not exist on a
     * server that has not opted in; 401 for a missing or wrong token.
     *
     * @param  Request  $request  Must carry `Authorization: Bearer <INSIGHTS_TOKEN>`.
     * @return JsonResponse The envelope with `data.users`.
     */
    public function index(Request $request): JsonResponse
    {
        $token = (string) config('analytics.insights_token');
        if ($token === '') {
            return $this->error(null, 'Not found', 404);
        }
        if (! hash_equals($token, (string) $request->bearerToken())) {
            return $this->error(null, 'Unauthorized', 401);
        }

        return $this->success(['users' => $this->insights->journeys()]);
    }
}
