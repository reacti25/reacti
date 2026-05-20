<?php

namespace App\Http\Controllers\Web\Backend\Pages;

use App\Http\Controllers\Controller;
use App\Models\PrivecyAndTerms;
use Illuminate\Http\JsonResponse;

/**
 * Read-only JSON endpoint for privacy/terms content.
 *
 * Exposes the stored `PrivecyAndTerms` records as JSON — consumed by the
 * mobile app / public pages to display legal copy. Renders no Blade view.
 */
class PrivacyPolicyController extends Controller
{
    /**
     * Return all privacy-and-terms records.
     *
     * @return JsonResponse JSON list of every `PrivecyAndTerms` row.
     */
    public function index()
    {
        $data = PrivecyAndTerms::get();

        return response()->json([
            'status' => 'success',
            'data' => $data,
        ], 200);
    }
}
