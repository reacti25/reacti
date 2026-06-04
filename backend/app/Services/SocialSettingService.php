<?php

namespace App\Services;

use App\Http\Controllers\Web\Backend\Settings\SocialController;
use Illuminate\Support\Facades\File;

/**
 * Business logic for the Google social-login admin settings screen.
 *
 * Extracted from {@see SocialController}
 * so the controller only validates input and shapes the view/redirect
 * responses. The service reads the current Google OAuth values from the
 * environment and rewrites the three `GOOGLE_*` lines in the project's
 * `.env` file. The `.env` rewrite (regex substitution + line break) is
 * reproduced verbatim — no behaviour change from the pre-refactor controller.
 */
class SocialSettingService
{
    /**
     * Read the current Google OAuth values from the environment.
     *
     * @return array ['google_client_id', 'google_client_secret',
     *               'google_redirect_url'] for the settings view.
     */
    public function currentSettings(): array
    {
        return [
            'google_client_id' => env('GOOGLE_CLIENT_ID', ''),
            'google_client_secret' => env('GOOGLE_CLIENT_SECRET', ''),
            'google_redirect_url' => env('GOOGLE_REDIRECT_URL', ''),
        ];
    }

    /**
     * Rewrite the three `GOOGLE_*` lines inside the project's `.env`.
     *
     * Reads the raw `.env`, swaps the credential lines via regex, and writes
     * it back — exactly as the pre-refactor controller did.
     *
     * @param  string|null  $clientId  The `GOOGLE_CLIENT_ID` value.
     * @param  string|null  $clientSecret  The `GOOGLE_CLIENT_SECRET` value.
     * @param  string|null  $redirectUrl  The `GOOGLE_REDIRECT_URL` value.
     */
    public function update(?string $clientId, ?string $clientSecret, ?string $redirectUrl): void
    {
        // Read the raw .env, swap the three Google lines, write it back.
        $envContent = File::get(base_path('.env'));
        $lineBreak = "\n";
        $envContent = preg_replace([
            '/GOOGLE_CLIENT_ID=(.*)\s*/',
            '/GOOGLE_CLIENT_SECRET=(.*)\s*/',
            '/GOOGLE_REDIRECT_URL=(.*)\s*/',
        ], [
            'GOOGLE_CLIENT_ID='.$clientId.$lineBreak,
            'GOOGLE_CLIENT_SECRET='.$clientSecret.$lineBreak,
            'GOOGLE_REDIRECT_URL='.$redirectUrl.$lineBreak,
        ], $envContent);

        File::put(base_path('.env'), $envContent);
    }
}
