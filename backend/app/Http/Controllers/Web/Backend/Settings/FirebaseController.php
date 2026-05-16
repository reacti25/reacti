<?php

namespace App\Http\Controllers\Web\Backend\Settings;

use App\Http\Controllers\Controller;
use Exception;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\File;

/**
 * Admin settings screen for the Firebase credentials (web guard).
 *
 * Backs the Firebase-settings routes in routes/backend.php. The `index`
 * action renders the `backend.layouts.settings.firebase_settings` Blade
 * view pre-filled from the `.env` file, and `update` writes the submitted
 * credentials back into `.env`.
 */
class FirebaseController extends Controller {
    /**
     * Display mail settings page.
     *
     * Reads the current Firebase credentials straight from the environment.
     *
     * @return View  The `backend.layouts.settings.firebase_settings` Blade view.
     */
    public function index(): View {
        $settings = [
            'firebase_credentials' => env('FIREBASE_CREDENTIALS', '')
        ];

        return view('backend.layouts.settings.firebase_settings', compact('settings'));
    }

    /**
     * Update mail settings.
     *
     * Rewrites the `FIREBASE_CREDENTIALS` line directly inside the project's
     * `.env` file via a regex substitution.
     *
     * @param Request $request  Body: firebase_credentials (optional string).
     * @return RedirectResponse  Redirect back with a success or error flash message.
     */
    public function update(Request $request): RedirectResponse {
        $request->validate([
            'firebase_credentials' => 'nullable|string'
        ]);

        try {
            // Read the raw .env, swap the credentials line, write it back.
            $envContent = File::get(base_path('.env'));
            $lineBreak  = "\n";
            $envContent = preg_replace([
                '/FIREBASE_CREDENTIALS=(.*)\s*/'
            ], [
                'FIREBASE_CREDENTIALS=' . $request->firebase_credentials . $lineBreak
            ], $envContent);

            File::put(base_path('.env'), $envContent);

            return back()->with('t-success', 'Updated successfully');
        } catch (Exception) {
            return back()->with('t-error', 'Failed to update');
        }
    }
}
