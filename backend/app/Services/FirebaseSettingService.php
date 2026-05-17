<?php

namespace App\Services;

use Illuminate\Support\Facades\File;

/**
 * Business logic for the Firebase-credentials admin settings screen.
 *
 * Extracted from {@see \App\Http\Controllers\Web\Backend\Settings\FirebaseController}
 * so the controller only validates input and shapes the view/redirect
 * responses. The service reads the current credentials from the environment
 * and rewrites the `FIREBASE_CREDENTIALS` line in the project's `.env`
 * file. The `.env` rewrite (regex substitution + line break) is reproduced
 * verbatim — no behaviour change from the pre-refactor controller.
 */
class FirebaseSettingService
{
    /**
     * Read the current Firebase credentials from the environment.
     *
     * @return array  ['firebase_credentials' => string] for the settings view.
     */
    public function currentSettings(): array
    {
        return [
            'firebase_credentials' => env('FIREBASE_CREDENTIALS', '')
        ];
    }

    /**
     * Rewrite the `FIREBASE_CREDENTIALS` line inside the project's `.env`.
     *
     * Reads the raw `.env`, swaps the credentials line via regex, and writes
     * it back — exactly as the pre-refactor controller did.
     *
     * @param  string|null  $firebaseCredentials  The credentials value to write.
     * @return void
     */
    public function update(?string $firebaseCredentials): void
    {
        // Read the raw .env, swap the credentials line, write it back.
        $envContent = File::get(base_path('.env'));
        $lineBreak  = "\n";
        $envContent = preg_replace([
            '/FIREBASE_CREDENTIALS=(.*)\s*/'
        ], [
            'FIREBASE_CREDENTIALS=' . $firebaseCredentials . $lineBreak
        ], $envContent);

        File::put(base_path('.env'), $envContent);
    }
}
