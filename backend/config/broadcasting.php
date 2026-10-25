<?php

/*
| Only the additions to Laravel's default broadcasting config; Laravel 11
| merges this file over the framework's own (connections included), so
| reverb/pusher/log/null still come from vendor/laravel/framework/config.
*/
return [

    /*
    | Connections every event is published to, comma-separated
    | (BROADCAST_FANOUT=reverb,reverb_legacy). Empty: the default only.
    | Read by App\Events\Concerns\BroadcastsToConfiguredConnections.
    */
    'fanout' => array_values(array_filter(array_map('trim', explode(',', (string) env('BROADCAST_FANOUT', ''))))),

    'connections' => [

        // The old agency's Reverb (climbiq-goonclimbers.com:8081), mirrored to
        // while installs of app < 1.8.1 exist. Same app id/key/secret. Never
        // throws: App\Broadcasting\LegacyReverbBroadcaster.
        'reverb_legacy' => [
            'driver' => 'reverb_legacy',
            'key' => env('REVERB_APP_KEY'),
            'secret' => env('REVERB_APP_SECRET'),
            'app_id' => env('REVERB_APP_ID'),
            'options' => [
                'host' => env('REVERB_LEGACY_HOST', 'climbiq-goonclimbers.com'),
                'port' => env('REVERB_LEGACY_PORT', 8081),
                'scheme' => 'https',
                'useTLS' => true,
            ],
            'client_options' => ['timeout' => 2, 'connect_timeout' => 2],
        ],

    ],

];
