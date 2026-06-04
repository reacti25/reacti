<?php

namespace Tests\Unit\Models;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pure-logic tests for the Room model. Rooms are the 1:1 chat
 * container — `user_one_id` is always the smaller of the two user
 * ids (enforced by RoomFactory's `between()` state to match the
 * controller's lookup pattern).
 *
 * Methods tested:
 *
 *   hasUser($id)              — does the room include this user
 *   getOtherUser($currentId)  — return the "not me" side
 *   scopeForUser($userId)     — rooms a user is in
 *   scopeBetweenUsers($a,$b)  — the canonical (sorted) room between two users
 *   unreadCountFor($userId)   — count of messages targeting this user, status != read
 */
class RoomTest extends TestCase
{
    use RefreshDatabase;

    /** `hasUser` is true for either participant of the room and false for anyone else. */
    #[Test]
    public function has_user_recognises_either_side(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();
        $eve = User::factory()->create();
        $room = Room::factory()->between($alice, $bob)->create();

        $this->assertTrue($room->hasUser($alice->id));
        $this->assertTrue($room->hasUser($bob->id));
        $this->assertFalse($room->hasUser($eve->id));
    }

    /** `getOtherUser` returns the participant that is *not* the given user id (the "not me" side). */
    #[Test]
    public function get_other_user_returns_the_opposite_side(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();
        $room = Room::factory()->between($alice, $bob)->create();

        $room->load(['userOne', 'userTwo']);

        $this->assertSame($bob->id, $room->getOtherUser($alice->id)->id);
        $this->assertSame($alice->id, $room->getOtherUser($bob->id)->id);
    }

    /** `forUser` returns every room the user belongs to (on either side) and excludes rooms they are not in. */
    #[Test]
    public function scope_for_user_returns_rooms_the_user_participates_in(): void
    {
        $me = User::factory()->create();
        $alice = User::factory()->create();
        $bob = User::factory()->create();
        $carol = User::factory()->create();
        $dave = User::factory()->create();

        $r1 = Room::factory()->between($me, $alice)->create();
        $r2 = Room::factory()->between($bob, $me)->create();
        $r3 = Room::factory()->between($carol, $dave)->create();

        $ids = Room::forUser($me->id)->pluck('id')->all();

        $this->assertEqualsCanonicalizing([$r1->id, $r2->id], $ids);
    }

    /**
     * `betweenUsers` finds the canonical room for a pair of users
     * regardless of argument order — the scope sorts the two ids
     * (min-first) before matching, so both orderings resolve to the
     * same room.
     */
    #[Test]
    public function scope_between_users_uses_min_max_convention(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();
        $room = Room::factory()->between($alice, $bob)->create();

        $found = Room::betweenUsers($alice->id, $bob->id)->first();
        $this->assertNotNull($found);
        $this->assertSame($room->id, $found->id);

        // Reversed input order — the scope itself enforces min-first so
        // it should still find the same room.
        $found2 = Room::betweenUsers($bob->id, $alice->id)->first();
        $this->assertNotNull($found2);
        $this->assertSame($room->id, $found2->id);
    }

    /**
     * `unreadCountFor` counts the room's messages addressed to the
     * given user whose status is not `read` — here two (sent +
     * delivered), excluding the already-read message and the one the
     * user sent themselves.
     */
    #[Test]
    public function unread_count_for_returns_messages_targeting_the_user_that_are_not_read(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();
        $room = Room::factory()->between($alice, $bob)->create();

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
