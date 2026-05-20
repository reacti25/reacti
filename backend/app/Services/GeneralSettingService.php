<?php

namespace App\Services;

use App\Helpers\Helper;
use App\Http\Controllers\Web\Backend\Settings\SettingController;
use App\Models\Setting;
use Illuminate\Http\Request;

/**
 * Business logic for the site-wide general settings admin screen.
 *
 * Extracted from {@see SettingController}
 * so the controller only validates input and shapes the view/redirect
 * responses. The service reads the settings row and performs the singleton
 * upsert, including replacing the logo/favicon uploads and removing the old
 * files. Any failure is re-thrown so the controller can build its error
 * flash message from the exception — no behaviour change from the
 * pre-refactor controller.
 */
class GeneralSettingService
{
    /**
     * Fetch the current settings row for the settings screen.
     *
     * @return Setting|null The latest settings row, or null when none exists.
     */
    public function currentSetting(): ?Setting
    {
        return Setting::latest('id')->first();
    }

    /**
     * Persist the system settings (singleton row, id 1).
     *
     * Replaces the logo/favicon images when new files are uploaded and
     * removes the old ones, then upserts the validated data against id 1.
     * Any exception is re-thrown for the controller's error handler.
     *
     * @param  Request  $request  The incoming request (logo, favicon files).
     * @param  array  $validatedData  The validated settings fields.
     * @return Setting The upserted settings row.
     *
     * @throws \Exception on any unexpected failure.
     */
    public function update(Request $request, array $validatedData): Setting
    {
        $setting = Setting::first();

        if ($request->hasFile('logo')) {
            // Delete the previous logo file before storing the new one.
            if ($setting && $setting->logo && file_exists(public_path($setting->logo))) {
                Helper::deleteImage(public_path($setting->logo));
            }
            // $validatedData['logo'] = Helper::uploadImage($request->file('logo'), 'settings', time() . '_' . Helper::getFileName($request->file('logo')));
            $validatedData['logo'] = Helper::uploadImage($request->logo, 'settings');
        }

        if ($request->hasFile('favicon')) {
            // Delete the previous favicon file before storing the new one.
            if ($setting && $setting->favicon && file_exists(public_path($setting->favicon))) {
                Helper::deleteImage(public_path($setting->favicon));
            }
            // $validatedData['favicon'] = Helper::uploadImage($request->file('favicon'), 'settings', time() . '_' . Helper::getFileName($request->file('favicon')));
            $validatedData['favicon'] = Helper::uploadImage($request->favicon, 'settings');
        }

        // Settings are a singleton row — always upsert against id 1.
        return Setting::updateOrCreate(
            [
                'id' => 1,
            ],
            $validatedData
        );
    }
}
