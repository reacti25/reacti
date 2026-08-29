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

        // The code must not be shown as COPY. It is now present once in the
        // page's script, where the funnel beacon needs it to know which invite
        // it is reporting — which leaks nothing, since the code is in the URL
        // the visitor followed to get here. What this guards is the demo's
        // payoff not carrying invite plumbing in front of the reader.
        $body = $resp->getContent();
        $this->assertSame(
            1,
            substr_count($body, 'landcode12'),
            'the code should appear only in the beacon script, never as copy',
        );
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
        // ...and ONLY that one. Two apps declared on one host means iOS has two
        // installed apps answering the same invite link and picks either: a
        // production link opening the staging app resolves the code against the
        // staging API, where it does not exist, so the user gets "Invite not
        // found" and the link bounces. The static files under public/.well-known
        // are what actually ship (nginx serves /.well-known/* without reaching
        // Laravel), and the deploy workflows pick the right one per host.
        $this->assertCount(1, $data['applinks']['details'][0]['appIDs']);

        $components = $data['applinks']['details'][0]['components'];
        // The catch-all must still be present, or no invite link ever opens
        // the app at all.
        $catchAll = array_values(array_filter(
            $components,
            fn ($c) => $c['/'] === '/i/*' && ! ($c['exclude'] ?? false),
        ));
        $this->assertCount(1, $catchAll);
    }

    /** `?web=1` links are excluded, and the exclusion is listed FIRST.
     *
     *  iOS takes the first matching component, so order is the whole fix: put
     *  the catch-all first and the exclusion is dead, the browser keeps handing
     *  the link back to the app, and the phone is unusable again. Get it
     *  backwards the other way and no invite link opens the app at all — which
     *  is why this is pinned rather than trusted to a code comment. */
    #[Test]
    public function aasa_excludes_already_handled_links_before_the_catch_all(): void
    {
        $components = $this->get('/.well-known/apple-app-site-association')
            ->json('applinks.details.0.components');

        $this->assertTrue($components[0]['exclude'] ?? false, 'the exclusion must come first');
        $this->assertSame('/i/*', $components[0]['/']);
        $this->assertSame(['web' => '1'], $components[0]['?']);

        // ...and the plain catch-all comes after it.
        $this->assertSame('/i/*', $components[1]['/']);
        $this->assertArrayNotHasKey('exclude', $components[1]);
    }

    /** An unknown code still renders the generic landing (no inviter, no 500). */
    #[Test]
    public function landing_page_handles_unknown_code(): void
    {
        $this->get('/i/nope404')->assertOk()->assertSee('id6755814897'); // store link
    }

    /** The two shipped AASA files each declare exactly ONE app — their own.
     *
     *  These static files are what actually reach the servers: nginx serves
     *  /.well-known/* without ever reaching Laravel, so the route above is
     *  effectively test-only. The deploy workflows pick the variant per host
     *  (staging-deploy swaps the `.staging` one in; backend-deploy deletes it).
     *
     *  Declaring both apps on one host is what made a production invite link
     *  open the STAGING app, which looked up the code against the staging API,
     *  did not find it, and left the user staring at "Invite not found". */
    #[Test]
    public function shipped_aasa_files_each_declare_only_their_own_app(): void
    {
        $dir = public_path('.well-known');

        $prod = json_decode(file_get_contents($dir.'/apple-app-site-association'), true);
        $this->assertSame(
            ['545264M5P7.com.reacti.app'],
            $prod['applinks']['details'][0]['appIDs'],
        );

        $staging = json_decode(file_get_contents($dir.'/apple-app-site-association.staging'), true);
        $this->assertSame(
            ['545264M5P7.com.reacti.app.staging'],
            $staging['applinks']['details'][0]['appIDs'],
        );

        // Both keep the ?web=1 exclusion first — see the ordering test above.
        foreach ([$prod, $staging] as $doc) {
            $components = $doc['applinks']['details'][0]['components'];
            $this->assertTrue($components[0]['exclude'] ?? false);
            $this->assertSame('/i/*', $components[1]['/']);
        }
    }

    /** The landing stamps its own URL `?web=1` as soon as it renders.
     *
     *  That is what the AASA exclusion keys off: a browser sitting on a
     *  stamped URL is no longer offered to the app, so a reload (WhatsApp's
     *  in-app browser reloads on every return) cannot bounce back into it. */
    #[Test]
    public function landing_page_marks_itself_web_handled(): void
    {
        $resp = $this->get('/i/democode12');
        $resp->assertOk();
        $resp->assertSee('replaceState', false);
        $resp->assertSee('web=1', false);
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
        // Reveal pairs the media with the viewer's reaction below it (the A/B
        // winner, folded in from the old /ib variant on 2026-08-04).
        $resp->assertSee('id="revealMedia"', false);
        $resp->assertSee('id="playback"', false);
        $resp->assertSee('your reaction');
        // The countdown ring — without it first-timers think the demo hung and
        // keep tapping the screen while they're being recorded.
        $resp->assertSee('id="timer"', false);
        $resp->assertSee('Get the Reacti app'); // the store call to action
    }
}
