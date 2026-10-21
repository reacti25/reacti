<?php

namespace App\Http\Controllers\Web\Backend\Settings;

use App\Http\Controllers\Controller;
use Illuminate\View\View;

/**
 * Admin settings screen for the Firebase credentials (web guard), read-only.
 *
 * The value lives in the environment (`.env` on Hostinger, SSM on AWS) and
 * is deployed, not edited here: a container's `.env` cannot be rewritten
 * (AWS plan, step 1.6). The page says where the credentials come from and
 * never shows the credentials themselves.
 */
class FirebaseController extends Controller
{
    public function index(): View
    {
        $credentials = (string) config('firebase.projects.app.credentials');
        $settings = [
            'firebase_credentials' => match (true) {
                $credentials === '' => 'Not set',
                str_starts_with($credentials, '{') => 'JSON service account from the environment',
                default => 'Service account file: '.$credentials,
            },
        ];

        return view('backend.layouts.settings.firebase_settings', compact('settings'));
    }
}
