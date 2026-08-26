<?php

use App\Models\DynamicPage;
use App\Services\InviteService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Apple App Site Association — declares that this domain's /i/* links belong to
// the Reacti app, so tapping an invite link opens the app (Universal Links).
// The app id is host-specific: the staging app owns staging.reacti.io, the
// production app owns reacti.io. Must be served as application/json, 200, no
// redirect (Apple's CDN fetches it).
Route::get('/.well-known/apple-app-site-association', function (Request $request) {
    $bundle = str_contains($request->getHost(), 'staging')
        ? 'com.reacti.app.staging'
        : 'com.reacti.app';

    return response()->json([
        'applinks' => [
            'details' => [
                [
                    'appIDs' => ["545264M5P7.{$bundle}"],
                    // ORDER MATTERS: iOS takes the FIRST matching component,
                    // so the exclusion has to precede the catch-all or it is
                    // never reached.
                    'components' => [
                        // The landing page stamps `?web=1` onto its own URL as
                        // soon as it renders. That marks the link as already
                        // handed over, so a browser that reloads the page - an
                        // in-app WhatsApp webview above all - cannot bounce
                        // back into the app. Without it the app opened, closed
                        // and reopened until the phone was unusable.
                        [
                            '/' => '/i/*',
                            '?' => ['web' => '1'],
                            'exclude' => true,
                            'comment' => 'Already handled once; leave it in the browser.',
                        ],
                        ['/' => '/i/*'],
                    ],
                ],
            ],
        ],
    ]);
});

// Personal-invite landing (Feature 5). The human-facing side of a shared
// reacti.io/i/{code} link: shows who invited them and how to connect. During
// closed testing there's no public App Store link, so it guides existing
// testers to the in-app "Connect with an inviter" code entry; when the app is
// public this page can redirect to the store / become a universal link.
Route::get('/i/{code}', function (string $code, InviteService $invites) {
    $invite = $invites->resolve($code);

    return view('invite', ['inviter' => $invite?->inviter, 'code' => $code]);
})->where('code', '[A-Za-z0-9]+')->name('invite.landing');

// NOTE: the unauthenticated `/run-migrate*`, `/run-composer-update`,
// `/run-db-seed`, `/run-cache-clear`, `/run-queue-restart`,
// `/run-optimize-clear` and `/run-storage-link` routes were removed —
// they let anyone wipe the database or run shell commands. Run those
// artisan commands over SSH on the server instead.

Route::get('privacy-policy', function () {
    $data = DynamicPage::where('page_slug', 'privacy-policy')->first();

    if (! $data) {
        $content = 'Privacy Policy data not found.';
    } else {
        $content = $data->page_content;
    }

    return view('privacy-policy', compact('content'));
})->name('privacy-policy');

// //Social login test routes
// Route::get('social-login/{provider}',[SocialLoginController::class,'RedirectToProvider'])->name('social.login');
// Route::get('social-login/{provider}/callback',[SocialLoginController::class,'HandleProviderCallback']);

// Broadcasting authentication route
Broadcast::routes(['middleware' => ['web', 'auth:web']]);

require __DIR__.'/auth.php';
