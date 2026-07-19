<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * View-once reactions + total erasure (P3, 1:1).
 *
 * A reaction to a one-time message is itself one-time: stored privately, sealed
 * for the media sender, and — when the media sender consumes it — the WHOLE
 * exchange (reaction + parent media row) is force-deleted. A reaction to an
 * ORDINARY message is unaffected, so the patent reaction path is preserved.
 */
class ViewOnceReactionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        Storage::fake('local');
    }

    /** A one-time media message from $sender to $receiver, with its room. */
    private function oneTimeMedia(User $sender, User $receiver): Chat
    {
        $room = Room::create(['user_one_id' => $sender->id, 'user_two_id' => $receiver->id]);

        return Chat::factory()->create([
            'sender_id' => $sender->id,
            'receiver_id' => $receiver->id,
            'room_id' => $room->id,
            'one_time' => true,
            'file' => 'viewonce/chat/media.jpg',
        ]);
    }

    /** A reaction replying to a one-time message is private, one-time, sealed. */
    #[Test]
    public function a_reaction_to_one_time_media_is_itself_one_time(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();
        $media = $this->oneTimeMedia($sender, $receiver);

        // The receiver uploads their reaction, exactly as the patent flow does.
        $this->actingAs($receiver, 'api')->post(
            "/api/auth/chat/send/{$sender->id}",
            [
                'message_type' => 'reaction',
                'reply_to_id' => $media->id,
                'file' => UploadedFile::fake()->create('reaction.mp4', 10, 'video/mp4'),
            ],
            ['Accept' => 'application/json'],
        )->assertOk();

        $reaction = Chat::where('message_type', 'reaction')->first();
        $this->assertTrue((bool) $reaction->one_time);
        $this->assertTrue((bool) $reaction->is_blurred);
        $this->assertStringStartsWith('viewonce/chat/', $reaction->getRawOriginal('file'));
        Storage::disk('local')->assertExists($reaction->getRawOriginal('file'));
    }

    /** A reaction to an ORDINARY message is unchanged — not one-time, public. */
    #[Test]
    public function a_reaction_to_ordinary_media_is_not_one_time(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();
        $room = Room::create(['user_one_id' => $sender->id, 'user_two_id' => $receiver->id]);
        $media = Chat::factory()->create([
            'sender_id' => $sender->id,
            'receiver_id' => $receiver->id,
            'room_id' => $room->id,
            'one_time' => false,
            'file' => 'uploads/chat/media.jpg',
        ]);

        $this->actingAs($receiver, 'api')->post(
            "/api/auth/chat/send/{$sender->id}",
            [
                'message_type' => 'reaction',
                'reply_to_id' => $media->id,
                'file' => UploadedFile::fake()->create('reaction.mp4', 10, 'video/mp4'),
            ],
            ['Accept' => 'application/json'],
        )->assertOk();

        $reaction = Chat::where('message_type', 'reaction')->first();
        $this->assertFalse((bool) $reaction->one_time);
        $this->assertFalse((bool) $reaction->is_blurred);
    }

    /** Consuming a one-time reaction erases the reaction AND its parent. */
    #[Test]
    public function consuming_the_reaction_erases_the_whole_exchange(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();
        $media = $this->oneTimeMedia($sender, $receiver);
        Storage::disk('local')->put('viewonce/chat/media.jpg', 'media-bytes');

        $reaction = Chat::factory()->create([
            'sender_id' => $receiver->id,
            'receiver_id' => $sender->id,
            'room_id' => $media->room_id,
            'message_type' => 'reaction',
            'reply_to_id' => $media->id,
            'one_time' => true,
            'consume_deadline' => now()->addMinutes(5),
            'file' => 'viewonce/chat/reaction.mp4',
        ]);
        Storage::disk('local')->put('viewonce/chat/reaction.mp4', 'reaction-bytes');

        // The media sender watches the reaction, then closes the viewer.
        $this->actingAs($sender, 'api')
            ->postJson("/api/auth/chat/one-time-media/{$reaction->id}/consume")
            ->assertOk();

        // Both files gone, both rows force-deleted — as if it never existed.
        Storage::disk('local')->assertMissing('viewonce/chat/reaction.mp4');
        Storage::disk('local')->assertMissing('viewonce/chat/media.jpg');
        $this->assertNull(Chat::withTrashed()->find($reaction->id));
        $this->assertNull(Chat::withTrashed()->find($media->id));
    }
}
