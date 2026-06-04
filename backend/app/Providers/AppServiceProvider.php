<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

/**
 * Application-wide service provider.
 *
 * The default provider Laravel registers for the application. Both the
 * `register` and `boot` hooks are currently empty — no custom container
 * bindings or bootstrap logic are wired up here yet.
 */
class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     *
     * Container bindings would go here; currently a no-op.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     *
     * Post-registration bootstrap logic would go here; currently a no-op.
     */
    public function boot(): void
    {
        //
    }
}
