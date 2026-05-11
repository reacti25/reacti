<?php

namespace Tests\Feature\Group;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Endpoint coverage for GroupMessageController. The full group
 * patent loop (send → mark-viewed → reaction) is exercised by
 * GroupReactionFlowTest. This file fills in editMessage,
 * getMessages, markAsRead, deleteMessages, plus auth/validation
 * for the rest.
 */
class GroupMessageControllerTest extends TestCase
{
    use RefreshDatabase;

    private function makeGroupWithMember(): array
    {
        $admin = User::factory()->create();
        $member = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $member->id,
        ]);
        return [$admin, $member, $group];
    }

    // -------- send --------

    #[Test]
    public function send_requires_auth(): void
    {
        $group = Group::factory()->create();
        $this->postJson("/api/auth/group/{$group->id}/send", ['text' => 'hi'])
            ->assertStatus(401);
    }

    #[Test]
    public function send_returns_403_for_non_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $stranger = User::factory()->create();

        $resp = $this->actingAs($stranger, 'api')->postJson(
            "/api/auth/group/{$group->id}/send",
            ['text' => 'sneaky'],
        );
        $resp->assertJsonPath('code', 403);
    }

    #[Test]
    public function send_validates_message_type(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/send",
            ['text' => 'hi', 'message_type' => 'bogus'],
        );
        $resp->assertStatus(422);
    }

    // -------- edit --------

    #[Test]
    public function edit_message_updates_sender_own_text(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id'  => $group->id,
            'sender_id' => $admin->id,
            'text'      => 'before',
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/message/{$msg->id}",
            ['text' => 'after'],
        );
        $resp->assertOk();
        $this->assertDatabaseHas('group_messages', [
            'id'   => $msg->id,
            'text' => 'after',
        ]);
    }

    #[Test]
    public function edit_message_rejects_non_owner(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id'  => $group->id,
            'sender_id' => $admin->id,
            'text'      => 'before',
        ]);

        $resp = $this->actingAs($member, 'api')->postJson(
            "/api/auth/group/{$group->id}/message/{$msg->id}",
            ['text' => 'hijacked'],
        );
        $resp->assertStatus(404);
    }

    #[Test]
    public function edit_message_validates_text(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id'  => $group->id,
            'sender_id' => $admin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/message/{$msg->id}",
            [],
        );
        $resp->assertStatus(422);
    }

    #[Test]
    public function edit_message_requires_auth(): void
    {
        $g = Group::factory()->create();
        $this->postJson("/api/auth/group/{$g->id}/message/1", ['text' => 'x'])
            ->assertStatus(401);
    }

    // -------- get messages --------

    #[Test]
    public function get_messages_returns_group_messages_for_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        GroupMessage::factory()->create([
            'group_id'  => $group->id,
            'sender_id' => $admin->id,
            'text'      => 'hello',
        ]);

        $resp = $this->actingAs($member, 'api')->getJson("/api/auth/group/{$group->id}/messages");
        $resp->assertOk();
        $resp->assertJsonPath('success', true);
    }

    #[Test]
    public function get_messages_returns_403_for_non_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $stranger = User::factory()->create();

        $resp = $this->actingAs($stranger, 'api')->getJson("/api/auth/group/{$group->id}/messages");
        $resp->assertStatus(403);
    }

    #[Test]
    public function get_messages_requires_auth(): void
    {
        $g = Group::factory()->create();
        $this->getJson("/api/auth/group/{$g->id}/messages")->assertStatus(401);
    }

    // -------- mark as read --------

    #[Test]
    public function mark_as_read_records_a_read_row(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id'  => $group->id,
            'sender_id' => $admin->id,
        ]);

        $resp = $this->actingAs($member, 'api')->postJson("/api/auth/group/{$group->id}/read");
        $resp->assertOk();

        $this->assertDatabaseHas('group_message_reads', [
            'group_message_id' => $msg->id,
            'user_id'          => $member->id,
        ]);
    }

    #[Test]
    public function mark_as_read_rejects_non_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $stranger = User::factory()->create();

        $resp = $this->actingAs($stranger, 'api')->postJson("/api/auth/group/{$group->id}/read");
        $resp->assertStatus(403);
    }

    // -------- mark viewed --------

    #[Test]
    public function mark_viewed_returns_403_for_non_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $stranger = User::factory()->create();
        $msg = GroupMessage::factory()->create([
            'group_id'  => $group->id,
            'sender_id' => $admin->id,
        ]);

        $resp = $this->actingAs($stranger, 'api')->postJson("/api/auth/group/mark-viewed/{$msg->id}");
        $resp->assertJsonPath('code', 403);
    }

    #[Test]
    public function mark_viewed_returns_404_for_unknown_message(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $resp = $this->actingAs($admin, 'api')->postJson('/api/auth/group/mark-viewed/999999');
        $resp->assertJsonPath('code', 404);
    }

    // -------- delete messages --------

    #[Test]
    public function delete_messages_admin_can_bulk_delete(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg1 = GroupMessage::factory()->create([
            'group_id'  => $group->id,
            'sender_id' => $admin->id,
        ]);
        $msg2 = GroupMessage::factory()->create([
            'group_id'  => $group->id,
            'sender_id' => $member->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->deleteJson(
            "/api/auth/group/{$group->id}/delete-messages",
            ['message_ids' => [$msg1->id, $msg2->id]],
        );
        $resp->assertOk();
        $this->assertSoftDeleted('group_messages', ['id' => $msg1->id]);
        $this->assertSoftDeleted('group_messages', ['id' => $msg2->id]);
    }

    #[Test]
    public function delete_messages_rejects_non_admin(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id'  => $group->id,
            'sender_id' => $admin->id,
        ]);

        $resp = $this->actingAs($member, 'api')->deleteJson(
            "/api/auth/group/{$group->id}/delete-messages",
            ['message_ids' => [$msg->id]],
        );
        $resp->assertStatus(403);
    }

    #[Test]
    public function delete_messages_validates_message_ids(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();

        $resp = $this->actingAs($admin, 'api')->deleteJson(
            "/api/auth/group/{$group->id}/delete-messages",
            ['message_ids' => [999999]],
        );
        $resp->assertStatus(422);
    }
}
