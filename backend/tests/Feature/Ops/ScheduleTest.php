<?php

namespace Tests\Feature\Ops;

use Illuminate\Console\Scheduling\Schedule;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins the schedule in routes/console.php (AWS plan, step 1.2): the staging
 * prune moved here from a GitHub Actions cron, and orphan media is swept
 * weekly. If either line is lost, staging fills up again silently.
 */
class ScheduleTest extends TestCase
{
    #[Test]
    public function staging_prune_runs_hourly_and_orphan_sweep_weekly(): void
    {
        $events = collect(app(Schedule::class)->events())
            ->mapWithKeys(fn ($e) => [preg_replace('/^.*artisan\S* /', '', $e->command) => $e->expression]);

        $this->assertSame('17 * * * *', $events->get('chat:prune-stale-staging'));
        $this->assertSame('30 4 * * 1', $events->get('media:prune-orphans --force'));
    }
}
