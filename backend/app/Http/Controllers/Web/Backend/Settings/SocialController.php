<?php

namespace App\Http\Controllers\Web\Backend\Settings;

use App\Http\Controllers\Controller;
use Illuminate\View\View;

/**
 * Admin settings screen for Google social login (web guard), read-only.
 *
 * The values live in the environment (`.env` on Hostinger, SSM on AWS) and
 * are deployed, not edited here: a container's `.env` cannot be rewritten
 * (AWS plan, step 1.6). The client secret is never shown.
 */
class SocialController extends Controller
{
    public function index(): View
    {
        $settings = [
            'google_client_id' => (string) config('services.google.client_id'),
            'google_client_secret' => config('services.google.client_secret') ? 'Set (hidden)' : 'Not set',
            'google_redirect_url' => (string) config('services.google.redirect'),
        ];

        return view('backend.layouts.settings.social_settings', compact('settings'));
    }
}
