<?php

use App\Models\DynamicPage;
use App\Services\InviteService;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
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
