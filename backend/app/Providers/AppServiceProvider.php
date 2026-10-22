<?php

namespace App\Providers;

use App\Broadcasting\LegacyReverbBroadcaster;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\ServiceProvider;

/**
 * Application-wide service provider.
 *
 * The default provider Laravel registers for the application. `boot` adds
 * the `reverb_legacy` broadcast driver (see config/broadcasting.php).
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
     * Registers the best-effort broadcaster for the old realtime server.
     */
    public function boot(): void
    {
        Broadcast::extend('reverb_legacy', fn ($app, array $config) => new LegacyReverbBroadcaster(Broadcast::pusher($config)));
    }
}
