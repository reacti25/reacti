<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote')->hourly();

// Sweep view-once media whose window has closed or is 48h old. The backstop
// behind the client's consume-on-close; a privacy guarantee, so it runs on
// every environment (not staging-only like chat:prune-stale-staging).
Schedule::command('chat:prune-view-once')->hourly();
