<?php

namespace Tests\Feature\Chat;

use App\Events\MessageDeletedEvent;
use App\Events\MessageReactionEvent;
use App\Events\MessageReadEvent;
use App\Events\MessageSendEvent;
use App\Events\OneTimeScreenshotEvent;
use App\Models\Chat;
use App\Models\User;
use App\Services\OneTimeMediaService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * One-time ("view once") media in 1:1 chats, end to end on the server:
 *
 *   sender sends a one-time photo -> recipient opens it (mark-viewed, the
 *   patent trigger) -> the recipient's reaction comes back and inherits the
 *   flag -> the sender watches it and reports done -> both rows and both
 *   files are gone and both phones are told.
 *
 * Also the edges: the link's signature and open window, the sweep that
 * finishes an exchange whose phone never reported done, the TTL, the
 * things a one-timer must not allow (forwarding, a quote thumbnail), and a
 * screenshot an iPhone reports.
 */
class OneTimeMediaTest extends TestCase
{
    use RefreshDatabase;

    private User $sender;

    private User $recipient;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Event::fake([
            MessageSendEvent::class,
            MessageReactionEvent::class,
            MessageReadEvent::class,
            MessageDeletedEvent::class,
            OneTimeScreenshotEvent::class,
        ]);
        $this->sender = User::factory()->create();
        $this->recipient = User::factory()->create();
    }

    /** The sender sends a one-time photo to the recipient. */
    private function sendOneTimePhoto(): Chat
    {
        $this->actingAs($this->sender, 'api')
            ->post("/api/auth/chat/send/{$this->recipient->id}", [
                'file' => UploadedFile::fake()->image('photo.jpg'),
                'message_type' => 'normal',
                'one_time' => 1,
            ])
            ->assertOk();

        return Chat::latest('id')->firstOrFail();
    }

    /** The recipient's silent reaction to [$media] is uploaded. */
    private function sendReactionTo(Chat $media): Chat
    {
        $this->actingAs($this->recipient, 'api')
            ->post("/api/auth/chat/send/{$this->sender->id}", [
                'file' => UploadedFile::fake()->create('reaction.mp4', 200, 'video/mp4'),
                'message_type' => 'reaction',
                'reply_to_id' => $media->id,
            ])
            ->assertOk();

        return Chat::latest('id')->firstOrFail();
    }

    /** [$viewer] marks [$chat] viewed (opens media / presses play on a reaction). */
    private function markViewed(User $viewer, Chat $chat): TestResponse
    {
        return $this->actingAs($viewer, 'api')->postJson("/api/auth/chat/mark-viewed/{$chat->id}");
    }

    /** The `file` link the conversation endpoint gives [$viewer] for [$chat]. */
    private function linkFor(User $viewer, Chat $chat): ?string
    {
        $peer = $viewer->is($this->sender) ? $this->recipient : $this->sender;
        $rows = $this->actingAs($viewer, 'api')
            ->getJson("/api/auth/chat/conversation/{$peer->id}")
            ->assertOk()
            ->json('data.chat');

        return collect($rows)->firstWhere('id', $chat->id)['file'] ?? null;
    }

    /** A one-time send is sealed like any media, flagged, and stored off the public disk. */
    #[Test]
    public function a_one_time_photo_is_stored_privately_and_still_sealed(): void
    {
        $media = $this->sendOneTimePhoto();

        $this->assertTrue($media->one_time);
        $this->assertTrue($media->is_blurred, 'one-time media must stay sealed: the seal drives the reaction recording');
        $this->assertStringStartsWith('one-time/chat/', $media->file);
        Storage::disk('local')->assertExists($media->file);
        $this->assertFileDoesNotExist(public_path($media->file));
    }

    /** Both the send response and the conversation carry the flag and a working link. */
    #[Test]
    public function the_flag_and_a_working_link_reach_the_recipient(): void
    {
        $media = $this->sendOneTimePhoto();

        $rows = $this->actingAs($this->recipient, 'api')
            ->getJson("/api/auth/chat/conversation/{$this->sender->id}")
            ->json('data.chat');
        $row = collect($rows)->firstWhere('id', $media->id);

        $this->assertTrue($row['is_one_time']);
        $this->assertSame('image', $row['media_type']);
        // No file extension: the live web server serves `*.jpg` as a static
        // file, so such a link would never reach the app.
        $this->assertMatchesRegularExpression('#/api/one-time-media/\d+/[0-9a-f]{64}$#', $row['file']);
        // No login on the fetch: the app's image widget sends no token.
        $this->get($row['file'])
            ->assertOk()
            ->assertHeader('Cache-Control', 'no-store, private');
        // Byte ranges: iPhone video playback will not start without them.
        $this->get($row['file'], ['Range' => 'bytes=0-1'])->assertStatus(206);
    }

    /** An ordinary send is untouched: public file, no flag. */
    #[Test]
    public function an_ordinary_photo_is_not_one_time(): void
    {
        $this->actingAs($this->sender, 'api')
            ->post("/api/auth/chat/send/{$this->recipient->id}", [
                'file' => UploadedFile::fake()->image('photo.jpg'),
                'message_type' => 'normal',
            ])
            ->assertOk()
            ->assertJsonPath('data.chat.is_one_time', false);

        $chat = Chat::latest('id')->firstOrFail();
        $this->assertStringStartsWith('uploads/chat/', $chat->file);
        @unlink(public_path($chat->file));
    }

    /** A link with a wrong signature serves nothing. */
    #[Test]
    public function a_forged_link_is_refused(): void
    {
        $media = $this->sendOneTimePhoto();

        $this->get("/api/one-time-media/{$media->id}/".str_repeat('0', 64))->assertNotFound();
    }

    /** Opening starts the window; once it has passed the link is dead and withheld. */
    #[Test]
    public function the_link_dies_when_the_open_window_closes(): void
    {
        $media = $this->sendOneTimePhoto();
        $link = $this->linkFor($this->recipient, $media);

        $this->markViewed($this->recipient, $media)->assertOk();
        $this->assertNotNull($media->fresh()->one_time_opened_at);
        $this->get($link)->assertOk();

        $this->travel(OneTimeMediaService::OPEN_WINDOW_MINUTES + 1)->minutes();

        $this->get($link)->assertNotFound();
        $this->assertNull($this->linkFor($this->recipient, $media));
        // The row stays as the "Opened" placeholder until the exchange ends.
        $this->assertDatabaseHas('chats', ['id' => $media->id]);
    }

    /** Opening a one-timer is the same patent trigger as any media. */
    #[Test]
    public function opening_one_time_media_still_marks_viewed_and_notifies_the_sender(): void
    {
        $media = $this->sendOneTimePhoto();

        $this->markViewed($this->recipient, $media)->assertOk();

        $media->refresh();
        $this->assertSame(1, $media->is_viewed);
        $this->assertFalse($media->is_blurred);
        Event::assertDispatched(MessageReadEvent::class);
    }

    /** The reaction to a one-timer is one-time too, whatever app recorded it. */
    #[Test]
    public function the_reaction_inherits_one_time_and_is_stored_privately(): void
    {
        $media = $this->sendOneTimePhoto();
        $this->markViewed($this->recipient, $media);

        $reaction = $this->sendReactionTo($media);

        $this->assertTrue($reaction->one_time);
        $this->assertStringStartsWith('one-time/chat/', $reaction->file);
        Event::assertDispatched(MessageSendEvent::class, 2);
        // The reaction event never announces a private path.
        Event::assertDispatched(MessageReactionEvent::class, fn ($event) => $event->reaction === null);
    }

    /** A reaction to ordinary media stays ordinary. */
    #[Test]
    public function a_reaction_to_ordinary_media_is_not_one_time(): void
    {
        $media = Chat::factory()->create([
            'sender_id' => $this->sender->id,
            'receiver_id' => $this->recipient->id,
            'message_type' => 'normal',
        ]);

        $reaction = $this->sendReactionTo($media);

        $this->assertFalse($reaction->one_time);
        @unlink(public_path($reaction->file));
    }

    /** THE LOOP: once the sender has watched the reaction, everything is gone. */
    #[Test]
    public function watching_the_reaction_erases_the_whole_exchange(): void
    {
        $media = $this->sendOneTimePhoto();
        $this->markViewed($this->recipient, $media);
        $reaction = $this->sendReactionTo($media);
        $this->markViewed($this->sender, $reaction)->assertOk();

        $this->actingAs($this->sender, 'api')
            ->postJson("/api/auth/chat/one-time/{$reaction->id}/finish")
            ->assertOk();

        // Hard delete: not even a soft-deleted row is left.
        $this->assertSame(0, Chat::withTrashed()->whereIn('id', [$media->id, $reaction->id])->count());
        Storage::disk('local')->assertMissing($media->file);
        Storage::disk('local')->assertMissing($reaction->file);
        // Both phones drop both bubbles.
        Event::assertDispatched(MessageDeletedEvent::class, fn ($e) => $e->chatId === $media->id);
        Event::assertDispatched(MessageDeletedEvent::class, fn ($e) => $e->chatId === $reaction->id);
    }

    /** A screenshot the recipient's iPhone reports is kept and told to the sender. */
    #[Test]
    public function a_screenshot_of_one_time_media_is_told_to_the_sender(): void
    {
        $media = $this->sendOneTimePhoto();
        $this->markViewed($this->recipient, $media);

        $this->actingAs($this->recipient, 'api')
            ->postJson("/api/auth/chat/one-time/{$media->id}/screenshot")
            ->assertOk();

        $this->assertNotNull($media->fresh()->one_time_screenshot_at);
        Event::assertDispatched(OneTimeScreenshotEvent::class, fn ($e) => $e->chatId === $media->id
            && $e->roomId === $media->room_id);
        // The sender's tile reads it from the conversation too.
        $row = collect($this->actingAs($this->sender, 'api')
            ->getJson("/api/auth/chat/conversation/{$this->recipient->id}")
            ->json('data.chat'))->firstWhere('id', $media->id);
        $this->assertTrue($row['one_time_screenshot']);
    }

    /** A second report changes nothing and tells the sender nothing new. */
    #[Test]
    public function a_repeated_screenshot_report_is_kept_once(): void
    {
        $media = $this->sendOneTimePhoto();
        $report = fn () => $this->actingAs($this->recipient, 'api')
            ->postJson("/api/auth/chat/one-time/{$media->id}/screenshot")
            ->assertOk();

        $report();
        $first = $media->fresh()->one_time_screenshot_at;
        $this->travel(5)->minutes();
        $report();

        $this->assertEquals($first, $media->fresh()->one_time_screenshot_at);
        Event::assertDispatchedTimes(OneTimeScreenshotEvent::class, 1);
    }

    /** Only the person who can see the message can report a screenshot of it. */
    #[Test]
    public function only_the_viewer_can_report_a_screenshot(): void
    {
        $media = $this->sendOneTimePhoto();
        $ordinary = Chat::factory()->create([
            'sender_id' => $this->sender->id,
            'receiver_id' => $this->recipient->id,
        ]);

        // The sender cannot mark their own one-timer.
        $this->actingAs($this->sender, 'api')
            ->postJson("/api/auth/chat/one-time/{$media->id}/screenshot")
            ->assertNotFound();
        // Nor is an ordinary message ever marked.
        $this->actingAs($this->recipient, 'api')
            ->postJson("/api/auth/chat/one-time/{$ordinary->id}/screenshot")
            ->assertNotFound();

        $this->assertNull($media->fresh()->one_time_screenshot_at);
        Event::assertNotDispatched(OneTimeScreenshotEvent::class);
    }

    /** Only the person the reaction was sent to can end the exchange. */
    #[Test]
    public function the_person_who_was_recorded_cannot_finish_the_exchange(): void
    {
        $media = $this->sendOneTimePhoto();
        $reaction = $this->sendReactionTo($media);

        $this->actingAs($this->recipient, 'api')
            ->postJson("/api/auth/chat/one-time/{$reaction->id}/finish")
            ->assertNotFound();

        $this->assertDatabaseHas('chats', ['id' => $reaction->id]);
    }

    /** Finish only ends one-time exchanges; an ordinary reaction is untouched. */
    #[Test]
    public function finish_refuses_an_ordinary_reaction(): void
    {
        $reaction = Chat::factory()->create([
            'sender_id' => $this->recipient->id,
            'receiver_id' => $this->sender->id,
            'message_type' => 'reaction',
        ]);

        $this->actingAs($this->sender, 'api')
            ->postJson("/api/auth/chat/one-time/{$reaction->id}/finish")
            ->assertNotFound();

        $this->assertDatabaseHas('chats', ['id' => $reaction->id]);
    }

    /** Force-quit safety: play was pressed, "done" never came, the next load erases. */
    #[Test]
    public function loading_the_chat_erases_an_exchange_whose_watch_window_lapsed(): void
    {
        $media = $this->sendOneTimePhoto();
        $this->markViewed($this->recipient, $media);
        $reaction = $this->sendReactionTo($media);
        $this->markViewed($this->sender, $reaction);

        $this->travel(OneTimeMediaService::OPEN_WINDOW_MINUTES + 1)->minutes();
        $rows = $this->actingAs($this->recipient, 'api')
            ->getJson("/api/auth/chat/conversation/{$this->sender->id}")
            ->json('data.chat');

        $this->assertSame([], $rows);
        $this->assertSame(0, Chat::withTrashed()->count());
        Storage::disk('local')->assertMissing($reaction->file);
    }

    /** A reaction that was never played keeps the exchange alive inside the TTL. */
    #[Test]
    public function an_unwatched_reaction_is_kept(): void
    {
        $media = $this->sendOneTimePhoto();
        $this->markViewed($this->recipient, $media);
        $reaction = $this->sendReactionTo($media);

        $this->travel(2)->days();

        $this->assertSame(0, app(OneTimeMediaService::class)->sweep());
        $this->assertNotNull($this->linkFor($this->sender, $reaction));
    }

    /** The TTL ends an exchange nobody finished, in every chat, via the command. */
    #[Test]
    public function the_prune_command_erases_exchanges_past_the_ttl(): void
    {
        $media = $this->sendOneTimePhoto();
        $this->markViewed($this->recipient, $media);
        $reaction = $this->sendReactionTo($media);

        $this->travel(OneTimeMediaService::TTL_DAYS + 1)->days();
        $this->artisan('chat:prune-one-time')
            ->expectsOutput('Erased 1 one-time exchange(s).')
            ->assertSuccessful();

        $this->assertSame(0, Chat::withTrashed()->count());
        Storage::disk('local')->assertMissing($media->file);
        Storage::disk('local')->assertMissing($reaction->file);
    }

    /** The sweep for one conversation leaves other people's exchanges alone. */
    #[Test]
    public function a_conversation_sweep_only_touches_that_conversation(): void
    {
        $this->sendOneTimePhoto();
        $this->travel(OneTimeMediaService::TTL_DAYS + 1)->days();
        $other = User::factory()->create();

        $this->assertSame(0, app(OneTimeMediaService::class)->sweep([$this->sender->id, $other->id]));
        $this->assertSame(1, Chat::count());
    }

    /** Forwarding would make a second copy, so a one-timer cannot be forwarded. */
    #[Test]
    public function one_time_media_cannot_be_forwarded(): void
    {
        $media = $this->sendOneTimePhoto();
        $target = User::factory()->create();

        $this->actingAs($this->recipient, 'api')->postJson('/api/auth/chat/forward', [
            'message_id' => $media->id,
            'source_type' => 'single',
            'recipients' => [['type' => 'single', 'id' => $target->id]],
        ]);

        $this->assertDatabaseMissing('chats', ['receiver_id' => $target->id]);
    }

    /** A reply that quotes one-time media never carries its file. */
    #[Test]
    public function quoting_one_time_media_shows_no_thumbnail(): void
    {
        $media = $this->sendOneTimePhoto();

        $this->actingAs($this->recipient, 'api')
            ->postJson("/api/auth/chat/send/{$this->sender->id}", ['text' => 'nice', 'reply_to_id' => $media->id])
            ->assertOk()
            ->assertJsonPath('data.chat.reply_to.id', $media->id)
            ->assertJsonPath('data.chat.reply_to.file', null);
    }

    /** "Delete for everyone" by the sender removes the private file too. */
    #[Test]
    public function deleting_one_time_media_for_everyone_removes_its_file(): void
    {
        $media = $this->sendOneTimePhoto();

        $this->actingAs($this->sender, 'api')
            ->deleteJson('/api/auth/chat/delete/chat/messages', ['message_id' => $media->id])
            ->assertOk();

        Storage::disk('local')->assertMissing($media->file);
    }
}
