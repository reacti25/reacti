<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Endpoint coverage for POST /api/auth/chat/forward — forwarding a message
 * to one or more recipients (1:1 chats and/or groups): fan-out, the
 * forwarded_from stamp, source authorization, and recipient skipping.
 */
class ForwardMessageTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    /** Create a 1:1 message from $from to $to (with their room). */
    private function chatMessage(User $from, User $to, array $overrides = []): Chat
    {
        $room = Room::factory()->between($from, $to)->create();

        return Chat::factory()->create(array_merge([
            'sender_id' => $from->id,
            'receiver_id' => $to->id,
            'room_id' => $room->id,
            'text' => 'hello there',
            'message_type' => 'normal',
        ], $overrides));
    }

    /** A group the given user is an admin member of. */
    private function groupWith(User $user): Group
    {
        $group = Group::factory()->create(['created_by' => $user->id]);
        GroupMember::factory()->admin()->create(['group_id' => $group->id, 'user_id' => $user->id]);

        return $group;
    }

    /** Forwards a 1:1 message to a single recipient, stamping forwarded_from. */
    #[Test]
    public function forwards_a_message_to_a_single_recipient(): void
    {
        $author = User::factory()->create();
        $peer = User::factory()->create();
        $target = User::factory()->create();
        $msg = $this->chatMessage($author, $peer, ['text' => 'forward me']);

        $resp = $this->actingAs($author, 'api')->postJson('/api/auth/chat/forward', [
            'message_id' => $msg->id,
            'source_type' => 'single',
            'recipients' => [['type' => 'single', 'id' => $target->id]],
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('data.forwarded_count', 1);
        $this->assertDatabaseHas('chats', [
            'sender_id' => $author->id,
            'receiver_id' => $target->id,
            'text' => 'forward me',
            'forwarded_from' => $author->id,
        ]);
    }

    /** Fans out to several recipients (a chat and a group) in one call. */
    #[Test]
    public function forwards_to_multiple_recipients(): void
    {
        $author = User::factory()->create();
        $peer = User::factory()->create();
        $target = User::factory()->create();
        $group = $this->groupWith($author);
        $msg = $this->chatMessage($author, $peer, ['text' => 'broadcast']);

        $resp = $this->actingAs($author, 'api')->postJson('/api/auth/chat/forward', [
            'message_id' => $msg->id,
            'source_type' => 'single',
            'recipients' => [
                ['type' => 'single', 'id' => $target->id],
                ['type' => 'group', 'id' => $group->id],
            ],
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('data.forwarded_count', 2);
        $this->assertDatabaseHas('chats', ['receiver_id' => $target->id, 'text' => 'broadcast']);
        $this->assertDatabaseHas('group_messages', [
            'group_id' => $group->id,
            'text' => 'broadcast',
            'forwarded_from' => $author->id,
        ]);
    }

    /** A group message can be the forward source when the caller is a member. */
    #[Test]
    public function forwards_a_group_message_source(): void
    {
        $author = User::factory()->create();
        $group = $this->groupWith($author);
        $target = User::factory()->create();
        $groupMsg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $author->id,
            'text' => 'from the group',
        ]);

        $resp = $this->actingAs($author, 'api')->postJson('/api/auth/chat/forward', [
            'message_id' => $groupMsg->id,
            'source_type' => 'group',
            'recipients' => [['type' => 'single', 'id' => $target->id]],
        ]);

        $resp->assertOk();
        $this->assertDatabaseHas('chats', ['receiver_id' => $target->id, 'text' => 'from the group']);
    }

    /** Cannot forward a message the caller neither sent nor received → 404. */
    #[Test]
    public function cannot_forward_a_message_you_cannot_see(): void
    {
        $author = User::factory()->create();
        $peerA = User::factory()->create();
        $peerB = User::factory()->create();
        $outsider = User::factory()->create();
        $msg = $this->chatMessage($peerA, $peerB); // outsider is neither party

        $this->actingAs($outsider, 'api')->postJson('/api/auth/chat/forward', [
            'message_id' => $msg->id,
            'source_type' => 'single',
            'recipients' => [['type' => 'single', 'id' => $author->id]],
        ])->assertStatus(404);
    }

    /** A group recipient the caller isn't a member of is silently skipped. */
    #[Test]
    public function skips_a_group_the_caller_is_not_in(): void
    {
        $author = User::factory()->create();
        $peer = User::factory()->create();
        $stranger = User::factory()->create();
        $foreignGroup = $this->groupWith($stranger); // author is NOT a member
        $msg = $this->chatMessage($author, $peer);

        $resp = $this->actingAs($author, 'api')->postJson('/api/auth/chat/forward', [
            'message_id' => $msg->id,
            'source_type' => 'single',
            'recipients' => [['type' => 'group', 'id' => $foreignGroup->id]],
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('data.forwarded_count', 0);
        $this->assertDatabaseMissing('group_messages', ['group_id' => $foreignGroup->id]);
    }

    /** No auth → 401. */
    #[Test]
    public function forward_requires_auth(): void
    {
        $this->postJson('/api/auth/chat/forward', [
            'message_id' => 1,
            'source_type' => 'single',
            'recipients' => [['type' => 'single', 'id' => 2]],
        ])->assertStatus(401);
    }

    /** Empty recipients → 422. */
    #[Test]
    public function forward_validates_recipients(): void
    {
        $author = User::factory()->create();
        $peer = User::factory()->create();
        $msg = $this->chatMessage($author, $peer);

        $this->actingAs($author, 'api')->postJson('/api/auth/chat/forward', [
            'message_id' => $msg->id,
            'source_type' => 'single',
            'recipients' => [],
        ])->assertStatus(422);
    }
}
