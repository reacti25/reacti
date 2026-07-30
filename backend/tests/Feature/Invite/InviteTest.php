<?php

namespace Tests\Feature\Invite;

use App\Models\Friend;
use App\Models\Invite;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Feature coverage for the personal-invite endpoints (Feature 5): minting a
 * code, resolving it to a public inviter profile, and one-tap connect.
 */
class InviteTest extends TestCase
{
    use RefreshDatabase;

    // -------- mint --------

    /** Minting requires auth. */
    #[Test]
    public function mint_requires_auth(): void
    {
        $this->postJson('/api/invites')->assertStatus(401);
    }

    /** Minting returns a code and is idempotent (one reusable code per user). */
    #[Test]
    public function mint_returns_a_stable_code(): void
    {
        $user = User::factory()->create();

        $first = $this->actingAs($user, 'api')->postJson('/api/invites');
        $first->assertOk()->assertJsonPath('success', true);
        $code = $first->json('data.code');
        $this->assertNotEmpty($code);

        // Second call returns the SAME code, and only one row exists.
        $second = $this->actingAs($user, 'api')->postJson('/api/invites');
        $this->assertSame($code, $second->json('data.code'));
        $this->assertSame(1, Invite::where('inviter_id', $user->id)->count());
    }

    // -------- resolve --------

    /** Resolving is public and returns only non-PII inviter fields. */
    #[Test]
    public function resolve_returns_public_inviter_without_pii(): void
    {
        $inviter = User::factory()->create([
            'first_name' => 'Jon', 'phone' => '+15551234567', 'email' => 'jon@example.com',
        ]);
        $invite = Invite::create(['inviter_id' => $inviter->id, 'code' => 'abc123xyz']);

        // No auth header — public route.
        $resp = $this->getJson("/api/invites/{$invite->code}");
        $resp->assertOk();
        $resp->assertJsonPath('data.first_name', 'Jon');
        $resp->assertJsonPath('data.id', $inviter->id);

        // Never leak PII on the public endpoint.
        $data = $resp->json('data');
        $this->assertArrayNotHasKey('phone', $data);
        $this->assertArrayNotHasKey('email', $data);
    }

    /** An unknown code is a 404. */
    #[Test]
    public function resolve_unknown_code_is_404(): void
    {
        $this->getJson('/api/invites/nope404')->assertStatus(404);
    }

    // -------- connect --------

    /** Connect requires auth. */
    #[Test]
    public function connect_requires_auth(): void
    {
        $this->postJson('/api/invites/whatever/connect')->assertStatus(401);
    }

    /** Connecting creates the mutual friendship with the inviter. */
    #[Test]
    public function connect_creates_mutual_friendship(): void
    {
        $inviter = User::factory()->create();
        $invitee = User::factory()->create();
        $invite = Invite::create(['inviter_id' => $inviter->id, 'code' => 'connectme1']);

        $this->actingAs($invitee, 'api')
            ->postJson("/api/invites/{$invite->code}/connect")
            ->assertOk()
            ->assertJsonPath('data.inviter_id', $inviter->id);

        $this->assertDatabaseHas('friends', ['user_id' => $inviter->id, 'friend_id' => $invitee->id]);
        $this->assertDatabaseHas('friends', ['user_id' => $invitee->id, 'friend_id' => $inviter->id]);
    }

    /** Connecting is idempotent — a second tap doesn't duplicate rows. */
    #[Test]
    public function connect_is_idempotent(): void
    {
        $inviter = User::factory()->create();
        $invitee = User::factory()->create();
        $invite = Invite::create(['inviter_id' => $inviter->id, 'code' => 'connectme2']);

        $this->actingAs($invitee, 'api')->postJson("/api/invites/{$invite->code}/connect")->assertOk();
        $this->actingAs($invitee, 'api')->postJson("/api/invites/{$invite->code}/connect")->assertOk();

        $this->assertSame(2, Friend::whereIn('user_id', [$inviter->id, $invitee->id])->count());
    }

    /** Connecting to your own code is a harmless no-op (no self-friendship). */
    #[Test]
    public function connect_to_own_code_is_a_noop(): void
    {
        $user = User::factory()->create();
        $invite = Invite::create(['inviter_id' => $user->id, 'code' => 'selfcode12']);

        $this->actingAs($user, 'api')->postJson("/api/invites/{$invite->code}/connect")->assertOk();

        $this->assertSame(0, Friend::where('user_id', $user->id)->count());
    }

    /** Connecting with an unknown code is a 404. */
    #[Test]
    public function connect_unknown_code_is_404(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user, 'api')->postJson('/api/invites/ghost999/connect')->assertStatus(404);
    }

    // -------- landing page --------

    /** The web landing at /i/{code} greets with the inviter and the App Store
     *  link (the download path for people without the app). The raw code is no
     *  longer surfaced — the demo's payoff shouldn't carry invite plumbing. */
    #[Test]
    public function landing_page_shows_inviter_and_store_link(): void
    {
        $inviter = User::factory()->create(['first_name' => 'Jon']);
        Invite::create(['inviter_id' => $inviter->id, 'code' => 'landcode12']);

        $resp = $this->get('/i/landcode12');
        $resp->assertOk();
        $resp->assertSee('Jon');
        $resp->assertSee('id6755814897'); // App Store link
        $resp->assertDontSee('landcode12'); // code no longer displayed
    }

    /** The Apple App Site Association is served as JSON with the app id + path,
     *  so tapping an invite link opens the app (Universal Links). */
    #[Test]
    public function aasa_declares_the_app_id_and_invite_path(): void
    {
        $resp = $this->get('/.well-known/apple-app-site-association');
        $resp->assertOk();

        $data = $resp->json();
        // Default test host resolves to the production bundle id.
        $this->assertSame('545264M5P7.com.reacti.app', $data['applinks']['details'][0]['appIDs'][0]);
        $this->assertSame('/i/*', $data['applinks']['details'][0]['components'][0]['/']);
    }

    /** An unknown code still renders the generic landing (no inviter, no 500). */
    #[Test]
    public function landing_page_handles_unknown_code(): void
    {
        $this->get('/i/nope404')->assertOk()->assertSee('id6755814897'); // store link
    }

    /** The landing ships the interactive web demo — the sealed clip, the skip
     *  flow and the demo pages — not just a static card. */
    #[Test]
    public function landing_page_ships_the_web_demo(): void
    {
        $resp = $this->get('/i/democode12');
        $resp->assertOk();
        $resp->assertSee('/demo/friend_moment.mp4'); // the sealed clip source
        $resp->assertSee('Tap to open');             // the sealed-media step
        $resp->assertSee('getUserMedia', false);     // browser camera demo wired
        $resp->assertSee('sure you want to skip', false); // skip-confirm popup
    }

    /** Variant B (/ib/{code}) is the same demo, but its reveal shows the media
     *  AND the viewer's reaction below it — the A/B alternative. */
    #[Test]
    public function landing_variant_b_reveal_shows_media_and_reaction(): void
    {
        $resp = $this->get('/ib/varbcode12');
        $resp->assertOk();
        $resp->assertSee('/demo/friend_moment.mp4');    // the demo still runs
        $resp->assertSee('getUserMedia', false);        // records the viewer too
        $resp->assertSee('id="revealMedia"', false);    // media shown on the reveal
        $resp->assertSee('id="playback"', false);       // reaction shown below it
        $resp->assertSee('your reaction');              // the paired caption
    }
}
