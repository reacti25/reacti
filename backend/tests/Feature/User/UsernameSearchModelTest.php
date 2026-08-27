<?php

namespace Tests\Feature\User;

use App\Models\User;
use App\Services\UserService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The discovery model on GET /user-list?mode=username.
 *
 * Achia, 2026-08-27: "i dont want one to be able to send requests to all just
 * like that." The username search matched `%term%`, so a single letter returned
 * every username containing it — browsing the directory, not searching it. That
 * matters more here than on a social network: opening a Reacti turns the
 * recipient's camera on, so being findable by a stranger is heavier than a
 * follow request.
 *
 * The model is Telegram-shaped (find who you can already name) with Instagram's
 * ranking idea on top: PREFIX from three characters, capped, friends first.
 *
 * Contacts search and friend-list search are deliberately NOT restricted — you
 * already know those people, so one letter should surface them.
 */
class UsernameSearchModelTest extends TestCase
{
    use RefreshDatabase;

    /** A query shorter than the minimum returns nobody at all. */
    #[Test]
    public function a_query_below_the_minimum_returns_no_one(): void
    {
        $me = User::factory()->create();
        User::factory()->create(['username' => '@dana_cohen']);
        User::factory()->create(['username' => '@david_levi']);

        foreach (['', 'd', 'da'] as $tooShort) {
            $resp = $this->actingAs($me, 'api')
                ->getJson("/api/user-list?mode=username&search={$tooShort}");

            $resp->assertOk();
            $this->assertCount(
                0,
                $resp->json('data.data') ?? $resp->json('data.users') ?? [],
                "'{$tooShort}' should surface nobody",
            );
        }
    }

    /** Three characters is enough, and it matches from the START of the handle. */
    #[Test]
    public function it_matches_a_prefix_not_a_substring(): void
    {
        $me = User::factory()->create();
        User::factory()->create(['username' => '@dana_cohen']);
        // Contains "dan" in the middle — a substring match would return this
        // too, which is exactly how one letter used to return half the table.
        User::factory()->create(['username' => '@yardan_mizrahi']);

        $resp = $this->actingAs($me, 'api')
            ->getJson('/api/user-list?mode=username&search=dan');

        $resp->assertOk();
        $names = collect($resp->json('data.data') ?? [])->pluck('username')->all();
        $this->assertContains('@dana_cohen', $names);
        $this->assertNotContains('@yardan_mizrahi', $names);
    }

    /** Typing the leading @ or leaving it off finds the same person. */
    #[Test]
    public function the_at_sign_is_optional(): void
    {
        $me = User::factory()->create();
        User::factory()->create(['username' => '@dana_cohen']);

        foreach (['dana', '@dana'] as $term) {
            $resp = $this->actingAs($me, 'api')
                ->getJson('/api/user-list?mode=username&search='.urlencode($term));

            $names = collect($resp->json('data.data') ?? [])->pluck('username')->all();
            $this->assertContains('@dana_cohen', $names, "'{$term}' should find the handle");
        }
    }

    /** However common the prefix, one query cannot reveal more than the cap. */
    #[Test]
    public function results_are_capped(): void
    {
        $me = User::factory()->create();
        for ($i = 0; $i < UserService::MAX_USERNAME_RESULTS + 15; $i++) {
            User::factory()->create(['username' => "@testuser{$i}"]);
        }

        // Ask for more than the cap explicitly — the cap has to win, or it is
        // just a default and anyone can page past it.
        $resp = $this->actingAs($me, 'api')
            ->getJson('/api/user-list?mode=username&search=testuser&per_page=100');

        $resp->assertOk();
        $this->assertLessThanOrEqual(
            UserService::MAX_USERNAME_RESULTS,
            count($resp->json('data.data') ?? []),
        );
    }

    /** Never yourself, however the query is shaped. */
    #[Test]
    public function it_never_returns_the_searcher(): void
    {
        $me = User::factory()->create(['username' => '@dana_cohen']);

        $resp = $this->actingAs($me, 'api')
            ->getJson('/api/user-list?mode=username&search=dana');

        $ids = collect($resp->json('data.data') ?? [])->pluck('id')->all();
        $this->assertNotContains($me->id, $ids);
    }

    /** No email address ever rides along in a discovery result. */
    #[Test]
    public function it_never_exposes_an_email_address(): void
    {
        $me = User::factory()->create();
        User::factory()->create([
            'username' => '@dana_cohen',
            'email' => 'dana@example.test',
        ]);

        $resp = $this->actingAs($me, 'api')
            ->getJson('/api/user-list?mode=username&search=dana');

        // Whole body, not just the shape: a stranger's address must not appear
        // anywhere in a response about discovery.
        $resp->assertDontSee('dana@example.test');
    }
}
