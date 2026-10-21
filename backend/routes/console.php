<?php

use Illuminate\Support\Facades\Schedule;

/*
|--------------------------------------------------------------------------
| Scheduled commands
|--------------------------------------------------------------------------
|
| Run by `php artisan schedule:work` (supervisor on Hostinger, the worker
| service on AWS; see docs/ops/worker.md). Minutes are off the hour so the
| jobs never collide with deploys or each other.
|
*/

// Staging only: hard-delete test chat data older than STAGING_PRUNE_HOURS.
// The command itself no-ops unless both gates in config/staging.php pass,
// so production runs it every hour and deletes nothing.
Schedule::command('chat:prune-stale-staging')
    ->hourlyAt(17)
    ->withoutOverlapping();

// Media files no live message or group points at (deletions before
// 2026-10 left files behind). Skips anything younger than an hour.
Schedule::command('media:prune-orphans --force')
    ->weeklyOn(1, '04:30')
    ->withoutOverlapping();
