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
 * Coverage for "delete for me" — a per-user hide that excludes a message from
 * the caller's fetches (on every device) while leaving it for everyone else.
 * Covers the 1:1 and group endpoints.
 */
class DeleteForMeTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    /** ids present in a 1:1 conversation response. */
    private function conversationIds($response): array
    {
        return collect($response->json('data.chat'))->pluck('id')->all();
    }

    /** A participant hides a message for themselves only; the peer still sees it. */
    #[Test]
    public function participant_hides_a_message_for_themselves_only(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();
        $msg = Chat::factory()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
            'text' => 'secret',
        ]);

        $this->actingAs($a, 'api')
            ->postJson('/api/auth/chat/delete-for-me', ['message_id' => $msg->id])
            ->assertOk();

        // The row is untouched (not soft-deleted) and a deletion is recorded.
        $this->assertDatabaseHas('chats', ['id' => $msg->id, 'deleted_at' => null]);
        $this->assertDatabaseHas('chat_message_deletions', [
            'chat_id' => $msg->id,
            'user_id' => $a->id,
        ]);

        // A no longer sees it; B still does.
        $aView = $this->actingAs($a, 'api')->getJson("/api/auth/chat/conversation/{$b->id}");
        $this->assertNotContains($msg->id, $this->conversationIds($aView));

        $bView = $this->actingAs($b, 'api')->getJson("/api/auth/chat/conversation/{$a->id}");
        $this->assertContains($msg->id, $this->conversationIds($bView));
    }

    /** A non-participant cannot hide someone else's message → 404. */
    #[Test]
    public function non_participant_cannot_delete_for_me(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $outsider = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();
        $msg = Chat::factory()->create([
            'sender_id' => $a->id,
            'receiver_id' => $b->id,
            'room_id' => $room->id,
        ]);

        $this->actingAs($outsider, 'api')
            ->postJson('/api/auth/chat/delete-for-me', ['message_id' => $msg->id])
            ->assertStatus(404);
    }

    /** No auth → 401. */
    #[Test]
    public function delete_for_me_requires_auth(): void
    {
        $this->postJson('/api/auth/chat/delete-for-me', ['message_id' => 1])
            ->assertStatus(401);
    }

    /** A group member hides a message for themselves; other members still see it. */
    #[Test]
    public function group_member_hides_a_message_for_themselves_only(): void
    {
        $owner = User::factory()->create();
        $member = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $owner->id]);
        GroupMember::factory()->admin()->create(['group_id' => $group->id, 'user_id' => $owner->id]);
        GroupMember::factory()->create(['group_id' => $group->id, 'user_id' => $member->id]);
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $owner->id,
            'text' => 'group secret',
        ]);

        $this->actingAs($member, 'api')
            ->postJson("/api/auth/group/message/{$msg->id}/delete-for-me")
            ->assertOk();

        $this->assertDatabaseHas('group_message_deletions', [
            'message_id' => $msg->id,
            'user_id' => $member->id,
        ]);

        $memberView = $this->actingAs($member, 'api')->getJson("/api/auth/group/{$group->id}/messages");
        $memberIds = collect($memberView->json('data.messages'))->pluck('id')->all();
        $this->assertNotContains($msg->id, $memberIds);

        $ownerView = $this->actingAs($owner, 'api')->getJson("/api/auth/group/{$group->id}/messages");
        $ownerIds = collect($ownerView->json('data.messages'))->pluck('id')->all();
        $this->assertContains($msg->id, $ownerIds);
    }

    /** A non-member cannot hide a group message → 404. */
    #[Test]
    public function non_member_cannot_delete_group_message_for_me(): void
    {
        $owner = User::factory()->create();
        $stranger = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $owner->id]);
        GroupMember::factory()->admin()->create(['group_id' => $group->id, 'user_id' => $owner->id]);
        $msg = GroupMessage::factory()->create(['group_id' => $group->id, 'sender_id' => $owner->id]);

        $this->actingAs($stranger, 'api')
            ->postJson("/api/auth/group/message/{$msg->id}/delete-for-me")
            ->assertStatus(404);
    }
}
