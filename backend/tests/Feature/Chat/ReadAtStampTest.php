<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Coverage for the `read_at` stamp — the exact time a 1:1 message was first
 * seen — set when the recipient opens the conversation or marks media viewed,
 * and surfaced in the message resource for the "Seen" details line.
 */
class ReadAtStampTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    /** Opening the conversation stamps read_at on the peer's messages, once. */
    #[Test]
    public function opening_conversation_stamps_read_at_on_received_messages(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();
        $msg = Chat::factory()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
            'text' => 'hi B',
        ]);
        $this->assertNull($msg->read_at);

        // B opens the conversation with A.
        $this->actingAs($b, 'api')->getJson("/api/auth/chat/conversation/{$a->id}")->assertOk();

        $fresh = $msg->fresh();
        $this->assertNotNull($fresh->read_at);
        $this->assertSame('read', $fresh->status);

        // First read wins: a second open does not move read_at.
        $firstReadAt = $fresh->read_at;
        $this->actingAs($b, 'api')->getJson("/api/auth/chat/conversation/{$a->id}")->assertOk();
        $this->assertEquals($firstReadAt, $msg->fresh()->read_at);
    }

    /** mark-viewed on media stamps read_at (the media "Seen" time). */
    #[Test]
    public function mark_viewed_stamps_read_at(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();
        $media = Chat::factory()->blurredMedia()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
        ]);

        $this->actingAs($b, 'api')->postJson("/api/auth/chat/mark-viewed/{$media->id}")->assertOk();

        $this->assertNotNull($media->fresh()->read_at);
    }

    /** The conversation response carries read_at (ISO string) for a read message. */
    #[Test]
    public function conversation_response_exposes_read_at(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();
        Chat::factory()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
            'text' => 'hi',
        ]);

        $resp = $this->actingAs($b, 'api')->getJson("/api/auth/chat/conversation/{$a->id}");
        $resp->assertOk();

        $first = collect($resp->json('data.chat'))->firstWhere('sender_id', $a->id);
        $this->assertNotNull($first);
        $this->assertArrayHasKey('read_at', $first);
        $this->assertNotNull($first['read_at']);
    }
}
