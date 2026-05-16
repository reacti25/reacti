<?php

namespace App\Http\Controllers\Web\Backend\Settings;


use Exception;
use App\Helper\Helper;
use App\Models\Setting;
use Illuminate\View\View;
use Illuminate\Http\Request;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;

/**
 * Admin screen for the site-wide general settings (web guard).
 *
 * Backs the general-settings routes in routes/backend.php. The `index`
 * action renders the `backend.layouts.settings.general_settings` Blade view
 * with the current `Setting` row; `update` persists branding/contact
 * details and the logo/favicon uploads.
 */
class SettingController extends Controller
{
    /**
     * Display the system settings page.
     *
     * @return View  The `backend.layouts.settings.general_settings` Blade view.
     */
    public function index(): View
    {
        $setting = Setting::latest('id')->first();
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
            $setting = Setting::first();
            if ($request->hasFile('logo')) {
                // Delete the previous logo file before storing the new one.
                if ($setting && $setting->logo && file_exists(public_path($setting->logo))) {
                    Helper::deleteImage(public_path($setting->logo));
                }
                // $validatedData['logo'] = Helper::uploadImage($request->file('logo'), 'settings', time() . '_' . Helper::getFileName($request->file('logo')));
                $validatedData['logo']  = Helper::uploadImage($request->logo, 'settings');
            }
            if ($request->hasFile('favicon')) {
                // Delete the previous favicon file before storing the new one.
                if ($setting && $setting->favicon && file_exists(public_path($setting->favicon))) {
                    Helper::deleteImage(public_path($setting->favicon));
                }
                // $validatedData['favicon'] = Helper::uploadImage($request->file('favicon'), 'settings', time() . '_' . Helper::getFileName($request->file('favicon')));
                $validatedData['favicon']  = Helper::uploadImage($request->favicon, 'settings');
            }

            // Settings are a singleton row — always upsert against id 1.
            Setting::updateOrCreate(
                [
                    'id' => 1
                ],
                $validatedData
            );
            return back()->with('t-success', 'Updated successfully');
        } catch (Exception $e) {
            return back()->with('t-error', 'Failed to update' . $e->getMessage());
        }
    }
}
