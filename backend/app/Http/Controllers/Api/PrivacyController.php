<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PrivacyService;

/**
 * Serves the static "privacy policy" content page to the API.
 *
 * Backs the public privacy-policy route, returning the `DynamicPage`
 * record stored under the `privacy-policy` slug so the client can
 * render the legal text without hardcoding it. This is a thin
 * controller — it delegates the lookup to {@see PrivacyService} and
 * builds the bespoke `response()->json` envelope (this controller does
 * not use the ApiResponse trait).
 */
class PrivacyController extends Controller
{
    /**
     * @param  PrivacyService  $privacyService  Privacy-page business logic.
     */
    public function __construct(private readonly PrivacyService $privacyService)
    {
        parent::__construct();
    }

    /**
     * Return the privacy-policy / terms dynamic page.
     *
     * Delegates to {@see PrivacyService::index()}.
     *
     * @return \Illuminate\Http\JsonResponse  The DynamicPage row for the
     *                                        `privacy-policy` slug (null if unset).
     */
    public function index()
    {
        $data = $this->privacyService->index();
        return response()->json([
            'status' => true,
            'message' => 'Privacy and Terms fetched successfully',
            'data' => $data
        ]);
    }
}
