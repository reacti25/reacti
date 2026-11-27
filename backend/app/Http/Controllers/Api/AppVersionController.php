<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use Illuminate\Http\JsonResponse;

/**
 * The newest app version per platform and where to get it, so an older app
 * can offer to update when it opens.
 *
 * The version is what the admin typed in the settings once the release was
 * live in its store (so nobody is sent to a store page that does not have it
 * yet); unset there, `REACTI_LATEST_IOS` / `REACTI_LATEST_ANDROID` from the
 * environment (the staging server sets them to test the prompt). Null on
 * both: no prompt.
 */
class AppVersionController extends Controller
{
    /**
     * Public (a phone not logged in may ask too) and cheap: one settings row.
     *
     * @return JsonResponse `data.ios` and `data.android`, each
     *                      `{latest_version, update_url}`.
     */
    public function show(): JsonResponse
    {
        $setting = Setting::query()->first();

        $platform = fn (string $name) => [
            'latest_version' => $setting?->{"latest_{$name}_version"} ?: config("reacti.latest_version.$name"),
            'update_url' => config("reacti.update_url.$name"),
        ];

        return response()->json([
            'success' => true,
            'message' => 'Latest app versions',
            'data' => ['ios' => $platform('ios'), 'android' => $platform('android')],
            'code' => 200,
        ]);
    }
}
