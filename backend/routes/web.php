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
//
// NOTE: in production this route is never reached. nginx serves /.well-known/*
// as static-only, so the real file is public/.well-known/apple-app-site-association
// and the deploy workflows swap in the per-host variant. This route is kept
// because it is what the test suite exercises, and it must stay in step with
// those files.
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

    // The first measurable step of the invite loop. Recorded server-side, so
    // the page needs no analytics script, no cookie and no consent banner for
    // people who have not even installed the app.
    $invites->recordFunnelStep($code, 'opened');

    return view('invite', ['inviter' => $invite?->inviter, 'code' => $code]);
})->where('code', '[A-Za-z0-9]+')->name('invite.landing');

// The two steps only the browser can see: the web demo reaching its reveal, and
// the store button being tapped. Posted to us rather than to a third party, and
// throttled because it is public and unauthenticated.
Route::post('/i/{code}/step/{step}', function (
    string $code,
    string $step,
    InviteService $invites,
) {
    $invites->recordFunnelStep($code, $step);

    // Always 204, whatever the code or step. This is a public endpoint, and an
    // answer that distinguishes a real code from a made-up one would turn it
    // into a way to enumerate invites.
    return response()->noContent();
})
    ->where('code', '[A-Za-z0-9]+')
    ->where('step', '[a-z_]+')
    ->middleware('throttle:30,1')
    ->name('invite.step');

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
