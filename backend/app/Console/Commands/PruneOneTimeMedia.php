<?php

namespace App\Console\Commands;

use App\Services\OneTimeMediaService;
use Illuminate\Console\Command;

/**
 * Erase every one-time exchange that is past its time, in every chat.
 *
 * The same sweep runs for one conversation whenever either person loads it
 * (see {@see OneTimeMediaService::sweep()}); this is the whole-server version
 * for exchanges nobody came back to. Safe to run as often as wanted: it only
 * touches exchanges whose window or TTL has already passed.
 *
 * Usage:
 *   php artisan chat:prune-one-time
 */
class PruneOneTimeMedia extends Command
{
    protected $signature = 'chat:prune-one-time';

    protected $description = 'Erase one-time media exchanges whose open window or TTL has passed.';

    public function handle(OneTimeMediaService $oneTimeMedia): int
    {
        $this->info('Erased '.$oneTimeMedia->sweep().' one-time exchange(s).');

        return self::SUCCESS;
    }
}
