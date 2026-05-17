<?php

namespace App\Services;

use App\Models\DynamicPage;

/**
 * Business logic for the static "privacy policy" content page.
 *
 * Extracted from {@see \App\Http\Controllers\Api\PrivacyController} so the
 * controller only shapes the response. That controller uses a bespoke
 * `response()->json` envelope rather than the ApiResponse trait, so this
 * service simply returns the model (or null) — it does not throw
 * {@see \App\Exceptions\ApiException}.
 */
class PrivacyService
{
    /**
     * Return the privacy-policy / terms dynamic page.
     *
     * @return DynamicPage|null  The DynamicPage row for the `privacy-policy`
     *                           slug, or null when the slug is unset.
     */
    public function index(): ?DynamicPage
    {
        return DynamicPage::where('page_slug', 'privacy-policy')->first();
    }
}
