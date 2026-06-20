<?php

namespace Tests\Feature\Analytics;

use App\Analytics\Analytics;
use App\Analytics\AnalyticsEvents;
use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\RecordingAnalyticsTransport;
use Tests\TestCase;

/**
 * The `media_persisted_seal_state` hook: saving a 1:1 media message emits one
 * metadata-only event recording its seal state at persist time (the server
 * mirror of the app's `media_received_seal_state`), via the `Chat::created`
 * listener in AnalyticsServiceProvider. Text messages do not emit it, and an
 * opted-out sender produces none.
 */
class MediaPersistedSealStateTest extends TestCase
{
    use RefreshDatabase;

    private RecordingAnalyticsTransport $transport;

    protected function setUp(): void
    {
        parent::setUp();
        // Rebind the emitter so the created-hook emits into a recorder.
        $this->transport = new RecordingAnalyticsTransport;
        $this->app->instance(
            Analytics::class,
            new Analytics($this->transport, 'staging', 'salt'),
        );
    }

    public function test_a_blurred_media_message_emits_seal_state_sealed(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();

        Chat::factory()->blurredMedia()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
        ]);

        $events = $this->transport->eventsNamed(AnalyticsEvents::MEDIA_PERSISTED_SEAL_STATE);
        $this->assertCount(1, $events);
        $this->assertSame('sealed', $events[0]['properties']['seal_state']);
        $this->assertSame('media', $events[0]['properties']['message_type']);
        $this->assertSame('private', $events[0]['properties']['scope']);
        // Sender is identified by a salted hash, never the raw id.
        $this->assertSame(
            hash('sha256', 'salt:'.$a->id),
            $events[0]['properties']['distinct_id'],
        );
    }

    public function test_unblurred_media_emits_seal_state_open(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();

        // Media that was stored without the blur flag — the bug this metric hunts.
        Chat::factory()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
            'file' => 'fake/path/photo.jpg',
            'file_type' => 'image',
            'is_blurred' => false,
            'text' => null,
        ]);

        $events = $this->transport->eventsNamed(AnalyticsEvents::MEDIA_PERSISTED_SEAL_STATE);
        $this->assertCount(1, $events);
        $this->assertSame('open', $events[0]['properties']['seal_state']);
    }

    public function test_a_group_media_message_emits_sealed_with_group_scope(): void
    {
        // Group blur intent is not on the message row; a normal media message
        // is sealed for recipients at persist time (derived from message_type).
        $sender = User::factory()->create();
        $group = Group::factory()->create();

        GroupMessage::factory()->withMedia()->create([
            'group_id' => $group->id,
            'sender_id' => $sender->id,
        ]);

        $events = $this->transport->eventsNamed(AnalyticsEvents::MEDIA_PERSISTED_SEAL_STATE);
        $this->assertCount(1, $events);
        $this->assertSame('sealed', $events[0]['properties']['seal_state']);
        $this->assertSame('media', $events[0]['properties']['message_type']);
        $this->assertSame('group', $events[0]['properties']['scope']);
    }

    public function test_a_group_reaction_message_emits_open(): void
    {
        // A reaction carries media but is never sealed — message_type drives it.
        $sender = User::factory()->create();
        $group = Group::factory()->create();

        GroupMessage::factory()->reaction()->create([
            'group_id' => $group->id,
            'sender_id' => $sender->id,
        ]);

        $events = $this->transport->eventsNamed(AnalyticsEvents::MEDIA_PERSISTED_SEAL_STATE);
        $this->assertCount(1, $events);
        $this->assertSame('open', $events[0]['properties']['seal_state']);
        $this->assertSame('reaction', $events[0]['properties']['message_type']);
        $this->assertSame('group', $events[0]['properties']['scope']);
    }

    public function test_a_text_message_does_not_emit_seal_state(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();

        Chat::factory()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
            'text' => 'hi',
            'file' => null,
            'message_type' => 'normal',
        ]);

        $this->assertEmpty(
            $this->transport->eventsNamed(AnalyticsEvents::MEDIA_PERSISTED_SEAL_STATE),
        );
    }

    public function test_opted_out_sender_emits_no_seal_state(): void
    {
        $a = User::factory()->create(['analytics_opt_out' => true]);
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();

        // The created-hook resolves opt-out from the acting api user.
        $this->actingAs($a, 'api');

        Chat::factory()->blurredMedia()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
        ]);

        $this->assertEmpty(
            $this->transport->eventsNamed(AnalyticsEvents::MEDIA_PERSISTED_SEAL_STATE),
        );
    }
}
