<?php

namespace App\Http\Controllers\Api\User;

use App\Http\Controllers\Controller;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

/**
 * Records a user's consent to the patented silent reaction-recording (DG1).
 *
 * Backs `POST /api/recording-consent` (authenticated). Consent is captured
 * once at registration and re-affirmable from the capture-point pop-up; this
 * endpoint is the server-side record that survives reinstall / new device and
 * provides an auditable proof of consent. It is purely additive — it writes a
 * new nullable column and changes no existing response shape.
 */
class RecordingConsentController extends Controller
{
    use ApiResponse;

    /**
     * Record the authenticated user's silent-recording consent.
     *
     * Idempotent and audit-stable: the original consent timestamp is preserved
     * on repeat calls, so it remains an accurate record of when consent was
     * first given.
     *
     * @return JsonResponse Standard envelope whose `data.recording_consent_at`
     *                      is the (newly set or pre-existing) consent timestamp.
     */
    public function store(): JsonResponse
    {
        $user = Auth::guard('api')->user();

        // Only set it the first time, so the stored timestamp is the moment
        // consent was actually given (not the latest re-affirmation).
        if (is_null($user->recording_consent_at)) {
            $user->update(['recording_consent_at' => now()]);
        }

        return $this->success(
            ['recording_consent_at' => $user->recording_consent_at],
            'Recording consent recorded.'
        );
    }
}
