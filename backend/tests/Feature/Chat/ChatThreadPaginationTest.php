<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Cursor pagination for the 1:1 conversation endpoint
 * (GET /api/auth/chat/conversation/{receiver_id}).
 *
 * Mirrors the group thread pagination: `limit` opts into cursor mode
 * (newest-first, `before=<id>` pages older, `has_more` computed from one extra
 * row); no `limit` keeps the full-thread shape unchanged for the live App Store
 * app and the admin panel.
 */
class ChatThreadPaginationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Seed a 1:1 thread of [$count] sequential messages (m0..m{n-1}, newest
     * last) from [$auth] to [$peer]; returns [auth, peer].
     *
     * @return array{0: User, 1: User}
     */
    private function threadWithMessages(int $count): array
    {
        $auth = User::factory()->create();
        $peer = User::factory()->create();

        for ($i = 0; $i < $count; $i++) {
            Chat::factory()->create([
                'sender_id' => $auth->id,
                'receiver_id' => $peer->id,
                'text' => "m$i",
                'created_at' => now()->subMinutes($count - $i),
            ]);
        }

        return [$auth, $peer];
    }

    #[Test]
    public function cursor_mode_returns_the_newest_page_with_has_more(): void
    {
        [$auth, $peer] = $this->threadWithMessages(100);

        $resp = $this->actingAs($auth, 'api')
            ->getJson("/api/auth/chat/conversation/{$peer->id}?limit=30");

        $resp->assertOk();
        $resp->assertJsonCount(30, 'data.chat');
        $resp->assertJsonPath('data.pagination.has_more', true);
        // Newest-first: newest present, a message from the next older page absent.
        $resp->assertJsonPath('data.chat.0.text', 'm99');
        $resp->assertJsonFragment(['text' => 'm70']); // 30th-newest, still page 1
        $resp->assertJsonMissing(['text' => 'm69']);   // first of the next older page
    }

    #[Test]
    public function cursor_before_returns_the_next_older_page_without_overlap(): void
    {
        [$auth, $peer] = $this->threadWithMessages(100);

        // m70 is the oldest on the newest page; the older page starts at m69.
        $before = Chat::where('sender_id', $auth->id)
            ->where('text', 'm70')->value('id');

        $resp = $this->actingAs($auth, 'api')
            ->getJson("/api/auth/chat/conversation/{$peer->id}?limit=30&before={$before}");

        $resp->assertOk();
        $resp->assertJsonCount(30, 'data.chat');
        $resp->assertJsonPath('data.chat.0.text', 'm69'); // newest of the older page
        $resp->assertJsonFragment(['text' => 'm40']);      // 30 older: m69..m40
        $resp->assertJsonMissing(['text' => 'm70']);       // no overlap with page 1
        $resp->assertJsonMissing(['text' => 'm99']);
        $resp->assertJsonPath('data.pagination.has_more', true);
    }

    #[Test]
    public function cursor_mode_reports_end_of_history(): void
    {
        [$auth, $peer] = $this->threadWithMessages(5);

        $resp = $this->actingAs($auth, 'api')
            ->getJson("/api/auth/chat/conversation/{$peer->id}?limit=30");

        $resp->assertOk();
        $resp->assertJsonCount(5, 'data.chat');
        $resp->assertJsonPath('data.pagination.has_more', false);
    }

    #[Test]
    public function cursor_limit_is_clamped_to_a_max(): void
    {
        [$auth, $peer] = $this->threadWithMessages(150);

        $resp = $this->actingAs($auth, 'api')
            ->getJson("/api/auth/chat/conversation/{$peer->id}?limit=99999");

        $resp->assertOk();
        // Clamped to 100, not the requested 99999.
        $this->assertSame(100, count($resp->json('data.chat')));
    }

    #[Test]
    public function the_no_param_response_keeps_the_full_pagination_shape(): void
    {
        // Back-compat guard: the live app's call (no params) still gets the
        // total/current_page/last_page/per_page block it has always received.
        [$auth, $peer] = $this->threadWithMessages(3);

        $resp = $this->actingAs($auth, 'api')
            ->getJson("/api/auth/chat/conversation/{$peer->id}");

        $resp->assertOk();
        $resp->assertJsonStructure([
            'data' => [
                'pagination' => ['total', 'current_page', 'last_page', 'per_page'],
            ],
        ]);
    }

    #[Test]
    public function loading_an_older_page_does_not_mark_messages_read(): void
    {
        // A load-older request carries `before`; only the initial open marks
        // read. Guards the read-receipt / patent-adjacent path from firing on
        // every scroll-up.
        [$auth, $peer] = $this->threadWithMessages(60);

        $unread = Chat::factory()->create([
            'sender_id' => $peer->id,
            'receiver_id' => $auth->id,
            'text' => 'unread from peer',
            'status' => 'sent',
            'created_at' => now(),
        ]);

        $before = Chat::where('sender_id', $auth->id)
            ->where('text', 'm30')->value('id');

        $this->actingAs($auth, 'api')
            ->getJson("/api/auth/chat/conversation/{$peer->id}?limit=20&before={$before}")
            ->assertOk();

        $this->assertSame(
            'sent',
            $unread->fresh()->status,
            'a load-older page must not mark the peer\'s messages read',
        );
    }
}
