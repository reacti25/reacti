<?php

namespace Tests\Unit\Models;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class RoomTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function has_user_recognises_either_side(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $eve   = User::factory()->create();
        $room  = Room::factory()->between($alice, $bob)->create();

        $this->assertTrue($room->hasUser($alice->id));
        $this->assertTrue($room->hasUser($bob->id));
        $this->assertFalse($room->hasUser($eve->id));
    }

    #[Test]
    public function get_other_user_returns_the_opposite_side(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $room  = Room::factory()->between($alice, $bob)->create();

        $room->load(['userOne', 'userTwo']);

        $this->assertSame($bob->id, $room->getOtherUser($alice->id)->id);
        $this->assertSame($alice->id, $room->getOtherUser($bob->id)->id);
    }

    #[Test]
    public function scope_for_user_returns_rooms_the_user_participates_in(): void
    {
        $me     = User::factory()->create();
        $alice  = User::factory()->create();
        $bob    = User::factory()->create();
        $carol  = User::factory()->create();
        $dave   = User::factory()->create();

        $r1 = Room::factory()->between($me, $alice)->create();
        $r2 = Room::factory()->between($bob, $me)->create();
        $r3 = Room::factory()->between($carol, $dave)->create();

        $ids = Room::forUser($me->id)->pluck('id')->all();

        $this->assertEqualsCanonicalizing([$r1->id, $r2->id], $ids);
    }

    #[Test]
    public function scope_between_users_uses_min_max_convention(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $room  = Room::factory()->between($alice, $bob)->create();

        $found = Room::betweenUsers($alice->id, $bob->id)->first();
        $this->assertNotNull($found);
        $this->assertSame($room->id, $found->id);

        // Reversed input order — the scope itself enforces min-first so
        // it should still find the same room.
        $found2 = Room::betweenUsers($bob->id, $alice->id)->first();
        $this->assertNotNull($found2);
        $this->assertSame($room->id, $found2->id);
    }

    #[Test]
    public function unread_count_for_returns_messages_targeting_the_user_that_are_not_read(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $room  = Room::factory()->between($alice, $bob)->create();

        // Two unread to bob, one read, one sent by bob (so it doesn't count).
        Chat::factory()->create([
            'sender_id' => $alice->id, 'receiver_id' => $bob->id,
            'room_id' => $room->id, 'status' => 'sent',
        ]);
        Chat::factory()->create([
            'sender_id' => $alice->id, 'receiver_id' => $bob->id,
            'room_id' => $room->id, 'status' => 'delivered',
        ]);
        Chat::factory()->create([
            'sender_id' => $alice->id, 'receiver_id' => $bob->id,
            'room_id' => $room->id, 'status' => 'read',
        ]);
        Chat::factory()->create([
            'sender_id' => $bob->id, 'receiver_id' => $alice->id,
            'room_id' => $room->id, 'status' => 'sent',
        ]);

        $this->assertSame(2, $room->unreadCountFor($bob->id));
    }
}
