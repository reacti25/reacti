<?php

namespace Tests\Feature\Group;

use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Broadcast;
use PHPUnit\Framework\Attributes\Test;
use Tests\Support\ThrowingBroadcaster;
use Tests\TestCase;

/**
 * A realtime fan-out failure must never fail an already-persisted chat write.
 *
 * Reproduces the reported group-chat bug: a sent message uploads to 100% and
 * then VANISHES for the sender (while still showing in the chat list and being
 * saved). Root cause — `sendMessage` persists the row and then runs a
 * SYNCHRONOUS broadcast; if that broadcast throws (Pusher down/misconfigured),
 * the request 500s after the DB write, the client treats the send as failed and
 * removes its optimistic bubble. These tests force a throwing broadcaster (the
 * suite normally uses a no-op driver, so this path was never exercised) and
 * assert the send/mark-viewed still succeed and persist.
 */
class GroupSendBroadcastTest extends TestCase
{
    use RefreshDatabase;

    /** Make every broadcast on the default connection throw. */
    private function useThrowingBroadcaster(): void
    {
        Broadcast::extend('throwing', fn () => new ThrowingBroadcaster);
        config([
            'broadcasting.default' => 'throwing',
            'broadcasting.connections.throwing' => ['driver' => 'throwing'],
        ]);
    }

    /** @return array{0: User, 1: User, 2: Group} */
    private function makeGroupWithMember(): array
    {
        $admin = User::factory()->create();
        $member = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $admin->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id' => $member->id,
        ]);

        return [$admin, $member, $group];
    }

    #[Test]
    public function group_send_survives_a_broadcast_failure(): void
    {
        $this->useThrowingBroadcaster();
        [$admin, $member, $group] = $this->makeGroupWithMember();

        $resp = $this->actingAs($member, 'api')->postJson(
            "/api/auth/group/{$group->id}/send",
            ['text' => 'hello group'],
        );

        // The persisted send must still report success to the client...
        $resp->assertOk();
        $resp->assertJsonPath('data.message.text', 'hello group');
        // ...and the message must be saved (so it never "vanishes" for the sender).
        $this->assertDatabaseHas('group_messages', [
            'group_id' => $group->id,
            'sender_id' => $member->id,
            'text' => 'hello group',
        ]);
    }

    #[Test]
    public function private_send_survives_a_broadcast_failure(): void
    {
        $this->useThrowingBroadcaster();
        $a = User::factory()->create();
        $b = User::factory()->create();
        Room::factory()->between($a, $b)->create();

        $resp = $this->actingAs($a, 'api')->postJson(
            "/api/auth/chat/send/{$b->id}",
            ['text' => 'hi there'],
        );

        $resp->assertOk();
        $this->assertDatabaseHas('chats', [
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'text' => 'hi there',
        ]);
    }

    #[Test]
    public function a_sent_group_message_comes_back_when_the_thread_is_re_fetched(): void
    {
        // The reload symptom: a sent group message stays at first but vanishes
        // after leaving and re-opening the group. That re-open re-fetches the
        // thread via getMessages — so the sender's own message MUST be in it.
        [$admin, $member, $group] = $this->makeGroupWithMember();

        $this->actingAs($member, 'api')
            ->postJson("/api/auth/group/{$group->id}/send", ['text' => 'hello reload'])
            ->assertOk();

        $resp = $this->actingAs($member, 'api')
            ->getJson("/api/auth/group/{$group->id}/messages");

        $resp->assertOk();
        // The sender must see their own message on re-fetch.
        $resp->assertJsonFragment(['text' => 'hello reload']);
        $resp->assertJsonFragment(['sender_id' => $member->id]);
    }

    #[Test]
    public function mark_viewed_survives_a_broadcast_failure(): void
    {
        // The patent trigger: if mark-viewed fails, the client never unblurs and
        // the silent reaction never records. A broadcast failure must not break it.
        $this->useThrowingBroadcaster();
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();
        $chat = Chat::factory()->blurredMedia()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
        ]);

        $resp = $this->actingAs($b, 'api')
            ->postJson("/api/auth/chat/mark-viewed/{$chat->id}");

        $resp->assertOk();
        $this->assertDatabaseHas('chats', [
            'id' => $chat->id,
            'is_viewed' => 1,
            'is_blurred' => 0,
        ]);
    }
}
