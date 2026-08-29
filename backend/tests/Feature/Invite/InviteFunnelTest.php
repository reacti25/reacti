<?php

namespace Tests\Feature\Invite;

use App\Models\Invite;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The invite loop, measured end to end.
 *
 * Reacti grows by invitation: a personal link, a web demo for people who have
 * not installed, and a Universal Link that connects both accounts on open. That
 * is a viral loop, and everything between "shared" and "connected" used to be
 * invisible — so there was no way to tell whether the web demo earned its place
 * or where the loop leaked.
 *
 * Counted on our own row rather than sent to a third party: the landing page is
 * public and anonymous, and an analytics script there would mean cookies and a
 * consent banner for people who have not even installed the app.
 */
class InviteFunnelTest extends TestCase
{
    use RefreshDatabase;

    private function invite(): Invite
    {
        return Invite::create([
            'code' => 'abc123',
            'inviter_id' => User::factory()->create()->id,
        ]);
    }

    /** Opening the landing page counts, without any client script. */
    #[Test]
    public function opening_the_landing_page_is_counted(): void
    {
        $invite = $this->invite();

        $this->get('/i/abc123')->assertOk();

        $invite->refresh();
        $this->assertSame(1, $invite->opened_count);
        $this->assertNotNull($invite->first_opened_at);
    }

    /** A link shared into a group chat is opened many times, and that IS reach. */
    #[Test]
    public function opens_accumulate_rather_than_flag(): void
    {
        $invite = $this->invite();

        $this->get('/i/abc123');
        $this->get('/i/abc123');
        $this->get('/i/abc123');

        $this->assertSame(3, $invite->refresh()->opened_count);
    }

    /** first_opened_at is the FIRST open, not the most recent. */
    #[Test]
    public function the_first_open_timestamp_does_not_move(): void
    {
        $invite = $this->invite();

        $this->get('/i/abc123');
        $first = $invite->refresh()->first_opened_at;

        $this->travel(1)->hours();
        $this->get('/i/abc123');

        $this->assertEquals($first, $invite->refresh()->first_opened_at);
    }

    /** The two steps only the browser can see. */
    #[Test]
    public function the_browser_can_report_demo_and_store_steps(): void
    {
        $invite = $this->invite();

        $this->post('/i/abc123/step/demo_completed')->assertNoContent();
        $this->post('/i/abc123/step/store_clicked')->assertNoContent();

        $invite->refresh();
        $this->assertSame(1, $invite->demo_completed_count);
        $this->assertSame(1, $invite->store_clicked_count);
    }

    /** An unknown code answers exactly like a real one. */
    #[Test]
    public function an_unknown_code_is_indistinguishable(): void
    {
        // Anything else turns a public endpoint into a way to enumerate which
        // invite codes exist.
        $this->post('/i/nosuchcode/step/demo_completed')->assertNoContent();
    }

    /** An unknown step writes nothing rather than guessing a column. */
    #[Test]
    public function an_unknown_step_is_ignored(): void
    {
        $invite = $this->invite();

        $this->post('/i/abc123/step/whatever')->assertNoContent();

        $invite->refresh();
        $this->assertSame(0, $invite->opened_count);
        $this->assertSame(0, $invite->demo_completed_count);
        $this->assertSame(0, $invite->store_clicked_count);
    }

    /** The page carries the beacon and a CSRF token for it. */
    #[Test]
    public function the_landing_page_ships_the_beacon(): void
    {
        $this->invite();

        $resp = $this->get('/i/abc123');
        $resp->assertSee('csrf-token', false);
        $resp->assertSee('reportStep', false);
        // The reveal is reached by four different paths; reporting from show()
        // is what stops one being missed and another double-counted.
        $resp->assertSee('demo_completed', false);
        $resp->assertSee('store_clicked', false);
    }
}
