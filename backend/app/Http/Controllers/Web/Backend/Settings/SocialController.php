<?php

namespace App\Http\Controllers\Web\Backend\Settings;

use App\Http\Controllers\Controller;
use App\Services\SocialSettingService;
use Exception;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

/**
 * Admin settings screen for Google social-login credentials (web guard).
 *
 * Backs the social-settings routes in routes/backend.php. The `index`
 * action renders the `backend.layouts.settings.social_settings` Blade view
 * pre-filled from `.env`, and `update` writes the Google OAuth credentials
 * back into the `.env` file.
 *
 * This is a thin controller: it validates input and shapes the
 * view/redirect responses. Reading the environment and rewriting the `.env`
 * file live in {@see SocialSettingService}.
 */
class SocialController extends Controller
{
    /**
     * @param  SocialSettingService  $socialSettingService  Google OAuth `.env` settings logic.
     */
    public function __construct(private readonly SocialSettingService $socialSettingService)
    {
        parent::__construct();
    }

    /**
     * Display mail settings page.
     *
     * Reads the current Google OAuth values straight from the environment.
     *
     * @return View The `backend.layouts.settings.social_settings` Blade view.
     */
    public function index(): View
    {
        $settings = $this->socialSettingService->currentSettings();

        return view('backend.layouts.settings.social_settings', compact('settings'));
    }

    /**
     * Update mail settings.
     *
     * Rewrites the three `GOOGLE_*` lines directly inside the project's
     * `.env` file via regex substitution.
     *
     * @param  Request  $request  Body: google_client_id, google_client_secret, google_redirect_url.
     * @return RedirectResponse Redirect back with a success or error flash message.
     */
    public function update(Request $request): RedirectResponse
    {
        $request->validate([
            'google_client_id' => 'nullable|string',
            'google_client_secret' => 'nullable|string',
            'google_redirect_url' => 'nullable|string',
        ]);

        try {
            $this->socialSettingService->update(
                $request->google_client_id,
                $request->google_client_secret,
                $request->google_redirect_url
            );

            return back()->with('t-success', 'Updated successfully');
        } catch (Exception) {
            return back()->with('t-error', 'Failed to update');
        }
    }
}
