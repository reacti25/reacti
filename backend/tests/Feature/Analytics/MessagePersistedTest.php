<?php

namespace Tests\Feature\Analytics;

use App\Analytics\Analytics;
use App\Analytics\AnalyticsEvents;
use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\RecordingAnalyticsTransport;
use Tests\TestCase;

/**
 * The `message_persisted` domain hook: saving a 1:1 or group message emits one
 * metadata-only event (type + scope + hashed sender), via the model `created`
 * listeners wired in AnalyticsServiceProvider.
 */
class MessagePersistedTest extends TestCase
{
    use RefreshDatabase;

    private RecordingAnalyticsTransport $transport;

    protected function setUp(): void
    {
        parent::setUp();
        // Rebind the emitter so the created-hooks emit into a recorder.
        $this->transport = new RecordingAnalyticsTransport;
        $this->app->instance(
            Analytics::class,
            new Analytics($this->transport, 'staging', 'salt'),
        );
    }

    public function test_creating_a_private_text_message_emits_message_persisted(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();

        Chat::factory()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
            'text' => 'hi',
            'message_type' => 'normal',
        ]);

        $events = $this->transport->eventsNamed(AnalyticsEvents::MESSAGE_PERSISTED);
        $this->assertCount(1, $events);
        $this->assertSame('private', $events[0]['properties']['scope']);
        $this->assertSame('text', $events[0]['properties']['message_type']);
        // Sender is identified by a salted hash, never the raw id.
        $this->assertSame(
            hash('sha256', 'salt:'.$a->id),
            $events[0]['properties']['distinct_id'],
        );
    }

    public function test_a_blurred_media_message_is_typed_media(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();

        Chat::factory()->blurredMedia()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
        ]);

        $events = $this->transport->eventsNamed(AnalyticsEvents::MESSAGE_PERSISTED);
        $this->assertCount(1, $events);
        $this->assertSame('media', $events[0]['properties']['message_type']);
    }
}
