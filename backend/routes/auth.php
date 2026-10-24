<?php

use App\Http\Controllers\Web\Auth\AuthenticatedSessionController;
use App\Http\Controllers\Web\Auth\NewPasswordController;
use App\Http\Controllers\Web\Auth\PasswordResetLinkController;
use Illuminate\Support\Facades\Route;

// Admin panel sign-in only. App users sign up through the API (OTP + age
// gate); the web /register page from the starter kit was removed because it
// created accounts that skipped both.
Route::middleware('guest')->group(function () {
    Route::get('login', [AuthenticatedSessionController::class, 'create'])
        ->name('login');

    Route::post('login', [AuthenticatedSessionController::class, 'store']);

    Route::get('forgot-password', [PasswordResetLinkController::class, 'create'])
        ->name('password.request');

    Route::post('forgot-password', [PasswordResetLinkController::class, 'store'])
        ->name('password.email');

    Route::get('reset-password/{token}', [NewPasswordController::class, 'create'])
        ->name('password.reset');

    Route::post('reset-password', [NewPasswordController::class, 'store'])
        ->name('password.store');
});

Route::middleware('auth')->group(function () {
    Route::post('logout', [AuthenticatedSessionController::class, 'destroy'])
        ->name('logout');
});
