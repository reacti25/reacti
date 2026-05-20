<?php

use App\Http\Middleware\AdminMiddleware;
use App\Http\Middleware\AuthCheckMiddleware;
use Illuminate\Auth\Middleware\Authenticate;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\Support\Facades\Route;
use Illuminate\View\Middleware\ShareErrorsFromSession;

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

        $middleware->appendToGroup('web', [
            // CorsMiddleware::class, // for CORS

            AddQueuedCookiesToResponse::class,
            StartSession::class,
            ShareErrorsFromSession::class,

            SubstituteBindings::class,
        ]);

        $middleware->alias([
            'auth' => Authenticate::class, // for web
            'auth.jwt' => AuthCheckMiddleware::class, // for API
            'admin' => AdminMiddleware::class,
        ]);
        $middleware->validateCsrfTokens(except: [
            'payment/stripe-webhook',
            'api/*',
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })->create();

// hello
