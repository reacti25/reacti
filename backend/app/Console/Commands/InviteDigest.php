<?php

namespace App\Console\Commands;

use App\Models\Invite;
use App\Services\InviteService;
use Illuminate\Console\Command;

/**
 * Print the invite loop as numbers: links minted, links opened, and what
 * happened on the landing page.
 *
 * The read-side companion to the counters {@see InviteService}
 * increments. It lives here rather than in the PostHog digest because these
 * counters are columns on the `invites` table, not analytics events - the
 * public landing page carries no third-party script, so the only record of a
 * web visit is the row Reacti already owns.
 *
 * Reports totals and rates only; it never names an inviter or prints a code.
 *
 * Usage (on the server):
 *   php artisan invites:digest
 *   php artisan invites:digest --days=30
 *
 * The app-side half of the loop - install, signup, connect - is in PostHog:
 *   python scripts/analytics/growth_digest.py
 */
class InviteDigest extends Command
{
    /** @var string */
    protected $signature = 'invites:digest {--days= : Only count invites minted in the last N days}';

    /** @var string */
    protected $description = 'Print the invite funnel: links minted, opened, demo completed, store tapped.';

    /**
     * Query the counters and print the funnel.
     *
     * @return int Always Command::SUCCESS - this only reads.
     */
    public function handle(): int
    {
        $days = $this->option('days');
        // Queried through the base builder rather than the model: this is a
        // pure aggregate read, and the aliases below are not Invite attributes.
        $query = Invite::query()->toBase();
        if ($days !== null) {
            $query->where('created_at', '>=', now()->subDays((int) $days));
        }

        // One aggregate pass. `opened_links` counts links opened at least once,
        // which is the denominator the later rates belong to - `opens` (every
        // open, including repeats) is reach, not people.
        $totals = $query->selectRaw(
            'count(*) as links,
             coalesce(sum(opened_count), 0) as opens,
             coalesce(sum(case when opened_count > 0 then 1 else 0 end), 0) as opened_links,
             coalesce(sum(demo_completed_count), 0) as demos,
             coalesce(sum(store_clicked_count), 0) as store_taps'
        )->first();

        $links = (int) $totals->links;
        if ($links === 0) {
            $this->line('No invites minted'.($days !== null ? " in the last {$days}d." : ' yet.'));

            return self::SUCCESS;
        }

        $opens = (int) $totals->opens;
        $openedLinks = (int) $totals->opened_links;
        $demos = (int) $totals->demos;
        $storeTaps = (int) $totals->store_taps;

        $window = $days !== null ? "last {$days}d" : 'all time';
        $this->line("Invite loop  |  {$window}");
        $this->line(str_repeat('=', 52));
        $this->line(sprintf('  %-26s %8d', 'Links minted', $links));
        $this->line(sprintf('  %-26s %8d   %s of links', 'Links opened at least once', $openedLinks, $this->rate($openedLinks, $links)));
        $this->line(sprintf('  %-26s %8d   %s per opened link', 'Opens in total', $opens, $this->ratio($opens, $openedLinks)));
        $this->line(sprintf('  %-26s %8d   %s of opens', 'Demo completed', $demos, $this->rate($demos, $opens)));
        $this->line(sprintf('  %-26s %8d   %s of opens', 'Store tapped', $storeTaps, $this->rate($storeTaps, $opens)));
        $this->line(str_repeat('=', 52));
        $this->line('  Store taps are where this half of the loop ends. Whether');
        $this->line('  a tap became an install and a connection is app-side:');
        $this->line('  python scripts/analytics/growth_digest.py');

        return self::SUCCESS;
    }

    /**
     * Format a share as a percentage, guarding a zero denominator.
     *
     * @param  int  $part  Numerator.
     * @param  int  $whole  Denominator; zero yields a dash rather than a divide.
     * @return string e.g. `42%`, or `-` when there is nothing to divide by.
     */
    private function rate(int $part, int $whole): string
    {
        if ($whole === 0) {
            return '-';
        }

        return round(100 * $part / $whole).'%';
    }

    /**
     * Format a per-item average to one decimal, guarding a zero denominator.
     *
     * @param  int  $part  Numerator.
     * @param  int  $whole  Denominator; zero yields a dash.
     * @return string e.g. `2.4`, or `-` when there is nothing to divide by.
     */
    private function ratio(int $part, int $whole): string
    {
        if ($whole === 0) {
            return '-';
        }

        return number_format($part / $whole, 1);
    }
}
