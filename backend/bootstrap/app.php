<?php

use App\Http\Middleware\AddServedByHeader;
use App\Http\Middleware\AdminMiddleware;
use App\Http\Middleware\AuthCheckMiddleware;
use App\Http\Middleware\TrackApiMetrics;
use App\Http\Middleware\TrustProxies;
use Illuminate\Auth\Middleware\Authenticate;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\Support\Facades\Route;
use Illuminate\View\Middleware\ShareErrorsFromSession;
use Sentry\Laravel\Integration;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        channels: __DIR__.'/../routes/channels.php',

        health: '/up',
        then: function () {
            Route::middleware(['web', 'auth', 'admin'])->prefix('admin')->group(base_path('routes/backend.php'));
        }
    )
    ->withBroadcasting(
        __DIR__.'/../routes/channels.php',
        ['prefix' => 'api', 'middleware' => ['auth:api']],
    )
    ->withMiddleware(function (Middleware $middleware) {
        // TLS ends at a proxy (CloudPanel's nginx, later the AWS load balancer);
        // believe its X-Forwarded-* headers. Which proxies: TRUSTED_PROXIES.
        $middleware->replace(Illuminate\Http\Middleware\TrustProxies::class, TrustProxies::class);
        // Health checks must keep answering during `artisan down`, or the load
        // balancer would pull every task the moment maintenance starts.
        $middleware->preventRequestsDuringMaintenance(except: ['up']);
        // X-Reacti-Origin: which origin answered (hostinger / aws), see SERVED_BY.
        $middleware->append(AddServedByHeader::class);

        $middleware->appendToGroup('web', [
            // CorsMiddleware::class, // for CORS

            AddQueuedCookiesToResponse::class,
            StartSession::class,
            ShareErrorsFromSession::class,

            SubstituteBindings::class,
        ]);

        // Observation-only API metrics (endpoint/method/status/latency).
        // Fire-and-forget; no-op when analytics is disabled.
        $middleware->appendToGroup('api', [
            TrackApiMetrics::class,
        ]);

        $middleware->alias([
            'auth' => Authenticate::class, // for web
            'auth.jwt' => AuthCheckMiddleware::class, // for API
            'admin' => AdminMiddleware::class,
        ]);
        $middleware->validateCsrfTokens(except: [
            'api/*',
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        // Report unhandled exceptions to Sentry. Inert when SENTRY_LARAVEL_DSN
        // is unset (default), so this changes nothing until configured.
        Integration::handles($exceptions);
    })->create();

// hello
