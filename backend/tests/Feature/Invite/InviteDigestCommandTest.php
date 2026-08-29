<?php

namespace Tests\Feature\Invite;

use App\Models\Invite;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Tests\TestCase;

/**
 * Covers `invites:digest` - the read side of the invite funnel counters.
 *
 * The command only reads, so what is worth pinning is that it reports the
 * right denominators (opens are repeatable, links are not), survives an empty
 * table, and never prints an invite code or an inviter.
 */
class InviteDigestCommandTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Create an invite with funnel counters already set.
     *
     * @param  array<string, int>  $counters  Column overrides for the counters.
     */
    private function inviteWith(array $counters): Invite
    {
        $invite = Invite::create([
            'code' => 'code'.User::count().random_int(1000, 9999),
            'inviter_id' => User::factory()->create()->id,
        ]);
        $invite->forceFill($counters)->save();

        return $invite;
    }

    public function test_it_reports_nothing_when_no_invites_exist(): void
    {
        $this->artisan('invites:digest')
            ->expectsOutputToContain('No invites minted')
            ->assertSuccessful();
    }

    public function test_it_counts_links_opens_and_landing_page_steps(): void
    {
        $this->inviteWith([
            'opened_count' => 8,
            'demo_completed_count' => 2,
            'store_clicked_count' => 1,
        ]);
        $this->inviteWith([
            'opened_count' => 2,
            'demo_completed_count' => 0,
            'store_clicked_count' => 1,
        ]);
        // Minted but never shared - the reason "links opened" needs its own
        // count rather than being assumed equal to "links".
        $this->inviteWith([]);

        $this->artisan('invites:digest')
            ->expectsOutputToContain('Links minted')
            ->assertSuccessful();

        $output = $this->digestOutput();
        $this->assertMatchesRegularExpression('/Links minted\s+3/', $output);
        $this->assertMatchesRegularExpression('/Links opened at least once\s+2/', $output);
        $this->assertMatchesRegularExpression('/Opens in total\s+10/', $output);
        $this->assertMatchesRegularExpression('/Demo completed\s+2/', $output);
        $this->assertMatchesRegularExpression('/Store tapped\s+2/', $output);
    }

    public function test_rates_are_taken_against_opens_not_links(): void
    {
        // 4 opens of one link, 1 store tap: 25% of opens, not 100% of links.
        $this->inviteWith(['opened_count' => 4, 'store_clicked_count' => 1]);

        $this->assertStringContainsString('25%', $this->digestOutput());
    }

    public function test_the_days_option_excludes_older_invites(): void
    {
        $old = $this->inviteWith(['opened_count' => 5]);
        $old->forceFill(['created_at' => now()->subDays(40)])->save();
        $this->inviteWith(['opened_count' => 1]);

        $output = $this->digestOutput(['--days' => 30]);
        $this->assertMatchesRegularExpression('/Links minted\s+1/', $output);
        $this->assertMatchesRegularExpression('/Opens in total\s+1/', $output);
        $this->assertStringContainsString('last 30d', $output);
    }

    public function test_it_never_prints_an_invite_code(): void
    {
        $invite = $this->inviteWith(['opened_count' => 3]);

        $this->assertStringNotContainsString($invite->code, $this->digestOutput());
    }

    /**
     * Run the command and return everything it printed.
     *
     * @param  array<string, mixed>  $options  Command options.
     */
    private function digestOutput(array $options = []): string
    {
        Artisan::call('invites:digest', $options);

        return Artisan::output();
    }
}
