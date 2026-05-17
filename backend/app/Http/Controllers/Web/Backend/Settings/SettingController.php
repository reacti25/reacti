<?php

namespace App\Http\Controllers\Web\Backend\Settings;


use App\Http\Controllers\Controller;
use App\Services\GeneralSettingService;
use Exception;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * Admin screen for the site-wide general settings (web guard).
 *
 * Backs the general-settings routes in routes/backend.php. The `index`
 * action renders the `backend.layouts.settings.general_settings` Blade view
 * with the current `Setting` row; `update` persists branding/contact
 * details and the logo/favicon uploads.
 *
 * This is a thin controller: it validates input and shapes the
 * view/redirect responses. Reading the settings row and the singleton
 * upsert (including the logo/favicon uploads) live in
 * {@see GeneralSettingService}.
 */
class SettingController extends Controller
{
    /**
     * @param  GeneralSettingService  $generalSettingService  General-settings business logic.
     */
    public function __construct(private readonly GeneralSettingService $generalSettingService)
    {
        parent::__construct();
    }

    /**
     * Display the system settings page.
     *
     * @return View  The `backend.layouts.settings.general_settings` Blade view.
     */
    public function index(): View
    {
        $setting = $this->generalSettingService->currentSetting();
        return view('backend.layouts.settings.general_settings', compact('setting'));
    }

    /**
     * Update the system settings.
     *
     * Persists the single settings row (id 1), replacing the logo/favicon
     * images when new files are uploaded and removing the old ones.
     *
     * @param Request $request  Body: name, title, description, phone, email,
     *                          copyright, keywords, author, address, logo, favicon.
     * @return RedirectResponse  Redirect back with a success or error flash message.
     */
    public function update(Request $request): RedirectResponse
    {
        $validatedData = $request->validate([
            'name'           => 'nullable',
            'title'          => 'nullable',
            'description'    => 'nullable',
            'phone'          => 'nullable',
            'email'          => 'nullable',
            'copyright'      => 'nullable',
            'keywords'       => 'nullable',
            'author'         => 'nullable',
            'address'        => 'nullable',
            'logo'           => 'nullable',
            'favicon'        => 'nullable',
        ]);

        try {
            $this->generalSettingService->update($request, $validatedData);
            return back()->with('t-success', 'Updated successfully');
        } catch (Exception $e) {
            return back()->with('t-error', 'Failed to update' . $e->getMessage());
        }
    }
}
