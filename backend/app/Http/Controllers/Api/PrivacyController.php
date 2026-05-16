<?php

namespace App\Http\Controllers\Api;

use App\Models\DynamicPage;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;

/**
 * Serves the static "privacy policy" content page to the API.
 *
 * Backs the public privacy-policy route, returning the `DynamicPage`
 * record stored under the `privacy-policy` slug so the client can
 * render the legal text without hardcoding it.
 */
class PrivacyController extends Controller
{
    /**
     * Return the privacy-policy / terms dynamic page.
     *
     * @return \Illuminate\Http\JsonResponse  The DynamicPage row for the
     *                                        `privacy-policy` slug (null if unset).
     */
    public function index()
    {
        $data = DynamicPage::where('page_slug', 'privacy-policy')->first();
        return response()->json([
            'status' => true,
            'message' => 'Privacy and Terms fetched successfully',
            'data' => $data
        ]);
    }
}
