<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Persists the authenticated user's analytics opt-out preference.
 *
 * Called by the app when the "Usage Data" toggle flips, so the backend can
 * honour the opt-out durably and across devices (the app also sends an
 * X-Analytics-Opt-Out header for the immediate case). While opted out the
 * backend emits no analytics event carrying this user's id.
 */
class AnalyticsOptOutController extends Controller
{
    /**
     * Set the current user's analytics opt-out flag.
     *
     * @param  Request  $request  Body: `opted_out` (bool, required).
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate(['opted_out' => ['required', 'boolean']]);

        $user = auth('api')->user();
        $user->analytics_opt_out = $data['opted_out'];
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Analytics preference updated',
            'data' => ['analytics_opt_out' => $user->analytics_opt_out],
            'code' => 200,
        ]);
    }
}
