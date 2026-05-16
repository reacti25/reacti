<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Session;

/**
 * Base controller every application controller extends.
 *
 * Runs once on instantiation of any child controller and performs
 * cross-cutting bootstrapping: it seeds default `locale` and `timezone`
 * values into the session, and refreshes the `last_activity_at` timestamp
 * of the currently authenticated user (whether logged in via the `web`
 * session guard or the `api` token guard). It declares no routes of its
 * own and renders no views.
 */
abstract class Controller
{
    /**
     * Bootstrap shared per-request state for every child controller.
     *
     * Invoked automatically when any controller that extends this class is
     * resolved out of the container.
     */
    public function __construct()
    {
        // Seed a default locale into the session on the first request so
        // translation lookups always have a value to work with.
        if(!Session::has('locale')) {
            $locale = 'en';
            Session::put('locale' , $locale);
            App::setLocale($locale);
        }

        // Seed a default timezone for date rendering when none is set yet.
        if(!Session::has('timezone')) {
            Session::put('timezone' , 'UTC');
        }

        // Touch the activity timestamp for a session-authenticated user so
        // online/last-seen indicators stay accurate across the admin panel.
        if (auth('web')->check()) {
            auth('web')->user()->update(['last_activity_at' => now()]);
        }

        // Same activity touch for a token-authenticated (mobile API) user.
        if (auth('api')->check()) {
            auth('api')->user()->update(['last_activity_at' => now()]);
        }
    }
}
