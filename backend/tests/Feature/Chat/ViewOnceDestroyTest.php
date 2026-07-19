<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\User;
use App\Services\ChatService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * View-once fetch window + destroy (P2d, 1:1).
 *
 * Pins that a one-time media file is fetchable only inside the claim window,
 * that mark-viewed opens that window, and that closing the viewer (the consume
 * endpoint) hard-deletes the file and nulls the pointer — the row surviving as
 * the "viewed once" placeholder.
 */
class ViewOnceDestroyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
    }

    /**
     * Create a claimed-or-unclaimed one-time chat with a file on the private
     * disk. Returns [sender, receiver, chat].
     */
    private function oneTimeChat(?\DateTimeInterface $deadline): array
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();
        $chat = Chat::factory()->create([
            'sender_id' => $sender->id,
            'receiver_id' => $receiver->id,
            'one_time' => true,
            'consume_deadline' => $deadline,
            'file' => 'viewonce/chat/secret.jpg',
        ]);
        Storage::disk('local')->put('viewonce/chat/secret.jpg', 'bytes');

        return [$sender, $receiver, $chat];
    }

    /** Before mark-viewed (no window) the media is not fetchable → 404. */
    #[Test]
    public function media_is_not_fetchable_before_the_claim_window_opens(): void
    {
        [, $receiver, $chat] = $this->oneTimeChat(null);

        $this->actingAs($receiver, 'api')
            ->get("/api/auth/chat/one-time-media/{$chat->id}")
            ->assertStatus(404);
    }

    /** mark-viewed opens the fetch window; the media then streams. */
    #[Test]
    public function mark_viewed_opens_the_window_and_the_media_streams(): void
    {
        [, $receiver, $chat] = $this->oneTimeChat(null);

        $this->actingAs($receiver, 'api')
            ->postJson("/api/auth/chat/mark-viewed/{$chat->id}")
            ->assertOk();

        $this->assertNotNull($chat->fresh()->consume_deadline);

        $this->actingAs($receiver, 'api')
            ->get("/api/auth/chat/one-time-media/{$chat->id}")
            ->assertOk();
    }

    /** After the window closes the media 404s even before the janitor runs. */
    #[Test]
    public function media_is_not_fetchable_after_the_window_closes(): void
    {
        [, $receiver, $chat] = $this->oneTimeChat(now()->subSecond());

        $this->actingAs($receiver, 'api')
            ->get("/api/auth/chat/one-time-media/{$chat->id}")
            ->assertStatus(404);
    }

    /** Consuming destroys the file and nulls the pointer; the row survives. */
    #[Test]
    public function consuming_destroys_the_file_and_keeps_the_row(): void
    {
        [, $receiver, $chat] = $this->oneTimeChat(now()->addMinutes(5));

        $this->actingAs($receiver, 'api')
            ->postJson("/api/auth/chat/one-time-media/{$chat->id}/consume")
            ->assertOk();

        Storage::disk('local')->assertMissing('viewonce/chat/secret.jpg');
        $fresh = $chat->fresh();
        $this->assertNotNull($fresh); // row kept as the "viewed once" placeholder
        $this->assertNull($fresh->getRawOriginal('file'));
    }

    /** A non-participant cannot consume — the file survives their call. */
    #[Test]
    public function a_non_participant_cannot_consume(): void
    {
        [, , $chat] = $this->oneTimeChat(now()->addMinutes(5));
        $eve = User::factory()->create();

        $this->actingAs($eve, 'api')
            ->postJson("/api/auth/chat/one-time-media/{$chat->id}/consume")
            ->assertOk(); // idempotent 200, but nothing destroyed

        Storage::disk('local')->assertExists('viewonce/chat/secret.jpg');
        $this->assertNotNull($chat->fresh()->getRawOriginal('file'));
    }

    /** The window length is the documented constant. */
    #[Test]
    public function the_fetch_window_matches_the_constant(): void
    {
        $this->assertSame(300, ChatService::ONE_TIME_FETCH_WINDOW_SECONDS);
    }
}
