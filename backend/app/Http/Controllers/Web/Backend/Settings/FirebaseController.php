<?php

namespace App\Http\Controllers\Web\Backend\Settings;

use App\Http\Controllers\Controller;
use App\Services\FirebaseSettingService;
use Exception;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

/**
 * Admin settings screen for the Firebase credentials (web guard).
 *
 * Backs the Firebase-settings routes in routes/backend.php. The `index`
 * action renders the `backend.layouts.settings.firebase_settings` Blade
 * view pre-filled from the `.env` file, and `update` writes the submitted
 * credentials back into `.env`.
 *
 * This is a thin controller: it validates input and shapes the
 * view/redirect responses. Reading the environment and rewriting the `.env`
 * file live in {@see FirebaseSettingService}.
 */
class FirebaseController extends Controller {
    /**
     * @param  FirebaseSettingService  $firebaseSettingService  Firebase `.env` settings logic.
     */
    public function __construct(private readonly FirebaseSettingService $firebaseSettingService)
    {
        parent::__construct();
    }

    /**
     * Display mail settings page.
     *
     * Reads the current Firebase credentials straight from the environment.
     *
     * @return View  The `backend.layouts.settings.firebase_settings` Blade view.
     */
    public function index(): View {
        $settings = $this->firebaseSettingService->currentSettings();

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
            $this->firebaseSettingService->update($request->firebase_credentials);

            return back()->with('t-success', 'Updated successfully');
        } catch (Exception) {
            return back()->with('t-error', 'Failed to update');
        }
    }
}
