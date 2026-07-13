<?php

namespace Tests\Feature\Group;

use App\Events\GroupMessageReadEvent;
use App\Events\GroupMessageViewedEvent;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
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

    /**
     * Build a group with one admin (the creator) and one regular
     * member. Returns [admin, member, group] for `actingAs($admin)`
     * vs `actingAs($member)` to exercise both permission paths.
     */
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

    // -------- send --------

    /** No auth → 401. */
    #[Test]
    public function send_requires_auth(): void
    {
        $group = Group::factory()->create();
        $this->postJson("/api/auth/group/{$group->id}/send", ['text' => 'hi'])
            ->assertStatus(401);
    }

    /**
     * Strangers can't send into a group they don't belong to. The
     * controller returns code:403 in the body. Critical: without this
     * check, anyone who knows a group id could spam its members.
     */
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

    /**
     * `message_type` is `nullable|in:normal,reaction` per the
     * validator. Anything else → 422. Same enum gate as the 1:1 chat.
     */
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

    /**
     * Happy path: the original sender edits their own text. The
     * `group_messages` row's text column changes; no other column
     * (sender_id, group_id, message_type) is allowed to drift via this
     * endpoint.
     */
    #[Test]
    public function edit_message_updates_sender_own_text(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'text' => 'before',
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/message/{$msg->id}",
            ['text' => 'after'],
        );
        $resp->assertOk();
        $this->assertDatabaseHas('group_messages', [
            'id' => $msg->id,
            'text' => 'after',
        ]);
    }

    /**
     * Someone other than the sender — even another group member —
     * can't edit. The controller scopes the lookup by sender_id so
     * the row is "not found" for non-owners. Returns 404 (not 403)
     * because the row genuinely doesn't exist for that user's
     * permissions.
     */
    #[Test]
    public function edit_message_rejects_non_owner(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'text' => 'before',
        ]);

        $resp = $this->actingAs($member, 'api')->postJson(
            "/api/auth/group/{$group->id}/message/{$msg->id}",
            ['text' => 'hijacked'],
        );
        $resp->assertStatus(404);
    }

    /** `text` is required per the edit validator → 422 if empty. */
    #[Test]
    public function edit_message_validates_text(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/message/{$msg->id}",
            [],
        );
        $resp->assertStatus(422);
    }

    /** No auth → 401. */
    #[Test]
    public function edit_message_requires_auth(): void
    {
        $g = Group::factory()->create();
        $this->postJson("/api/auth/group/{$g->id}/message/1", ['text' => 'x'])
            ->assertStatus(401);
    }

    /**
     * Editing within the window stamps `edited_at`, so the message
     * serializes with `is_edited: true`.
     */
    #[Test]
    public function edit_message_stamps_edited_at(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'text' => 'before',
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/message/{$msg->id}",
            ['text' => 'after'],
        );
        $resp->assertOk();
        $resp->assertJsonPath('data.message.is_edited', true);
        $this->assertNotNull($msg->fresh()->edited_at);
    }

    /** Past the 10-minute window the edit is refused with 422. */
    #[Test]
    public function edit_message_rejected_after_window(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'text' => 'before',
        ]);
        $msg->created_at = now()->subMinutes(11);
        $msg->save();

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/message/{$msg->id}",
            ['text' => 'too late'],
        );
        $resp->assertStatus(422);
        $this->assertDatabaseHas('group_messages', ['id' => $msg->id, 'text' => 'before']);
    }

    /** A reaction clip has no editable text → 404. */
    #[Test]
    public function edit_message_rejects_reaction(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'message_type' => 'reaction',
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/message/{$msg->id}",
            ['text' => 'nope'],
        );
        $resp->assertStatus(404);
    }

    // -------- get messages --------

    /**
     * Members can read the group's messages. Smoke test — the exact
     * shape is owned by MessageResource; we just check success:true.
     */
    #[Test]
    public function get_messages_returns_group_messages_for_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'text' => 'hello',
        ]);

        $resp = $this->actingAs($member, 'api')->getJson("/api/auth/group/{$group->id}/messages");
        $resp->assertOk();
        $resp->assertJsonPath('success', true);
    }

    /** Strangers cannot peek at group messages → 403. */
    #[Test]
    public function get_messages_returns_403_for_non_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $stranger = User::factory()->create();

        $resp = $this->actingAs($stranger, 'api')->getJson("/api/auth/group/{$group->id}/messages");
        $resp->assertStatus(403);
    }

    /** No auth → 401. */
    #[Test]
    public function get_messages_requires_auth(): void
    {
        $g = Group::factory()->create();
        $this->getJson("/api/auth/group/{$g->id}/messages")->assertStatus(401);
    }

    /**
     * A reaction's "watched" dot greens only when the ORIGINAL media sender
     * watches it — not any member. Marking the reaction viewed broadcasts
     * GroupMessageViewedEvent only for the media sender (the sender of the
     * message the reaction replies to), and is withheld when they have read
     * receipts off (reciprocal). A non-media-sender view broadcasts nothing.
     */
    #[Test]
    public function mark_viewed_broadcasts_group_viewed_event_only_for_media_sender(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();

        // $member sent the media; $admin's reaction replies to it, so $member
        // is the "media sender" whose watch should green the dot.
        $media = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $member->id,
            'text' => 'media',
        ]);
        $reaction = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'message_type' => 'reaction',
            'reply_to_message_id' => $media->id,
        ]);

        // A non-media-sender member viewing must NOT broadcast (false-green bug).
        $other = User::factory()->create();
        GroupMember::factory()->create(['group_id' => $group->id, 'user_id' => $other->id]);
        Event::fake([GroupMessageViewedEvent::class]);
        $this->actingAs($other, 'api')
            ->postJson("/api/auth/group/mark-viewed/{$reaction->id}")->assertOk();
        Event::assertNotDispatched(GroupMessageViewedEvent::class);

        // The media sender viewing, receipts on → event dispatched to the sender.
        Event::fake([GroupMessageViewedEvent::class]);
        $member->update(['read_receipts' => true]);
        $this->actingAs($member, 'api')
            ->postJson("/api/auth/group/mark-viewed/{$reaction->id}")->assertOk();
        Event::assertDispatched(GroupMessageViewedEvent::class);

        // Media sender viewing, receipts off → withheld.
        Event::fake([GroupMessageViewedEvent::class]);
        $member->update(['read_receipts' => false]);
        $this->actingAs($member, 'api')
            ->postJson("/api/auth/group/mark-viewed/{$reaction->id}")->assertOk();
        Event::assertNotDispatched(GroupMessageViewedEvent::class);
    }

    /**
     * Completing "all other members read" broadcasts GroupMessageReadEvent to
     * the sender (live text double-check), but only on the read that finishes
     * the set — earlier partial reads broadcast nothing.
     */
    #[Test]
    public function mark_as_read_broadcasts_read_event_only_once_all_others_read(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $member2 = User::factory()->create();
        GroupMember::factory()->create(['group_id' => $group->id, 'user_id' => $member2->id]);
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'text' => 'hi all',
        ]);

        // First of two other members reads → not everyone yet → no broadcast.
        Event::fake([GroupMessageReadEvent::class]);
        $this->actingAs($member, 'api')->postJson("/api/auth/group/{$group->id}/read")->assertOk();
        Event::assertNotDispatched(GroupMessageReadEvent::class);

        // Last member reads → seen-by-all → broadcast to the sender.
        Event::fake([GroupMessageReadEvent::class]);
        $this->actingAs($member2, 'api')->postJson("/api/auth/group/{$group->id}/read")->assertOk();
        Event::assertDispatched(
            GroupMessageReadEvent::class,
            fn (GroupMessageReadEvent $e): bool => (int) $e->messageId === $msg->id
                && (int) $e->senderId === $admin->id,
        );
    }

    /**
     * `seen_by_all` is true only once EVERY other member has read the auth
     * user's own message — it drives the group text double-check. With two
     * other members it stays false until both have read.
     */
    #[Test]
    public function get_messages_reports_seen_by_all_only_when_everyone_read(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $member2 = User::factory()->create();
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id' => $member2->id,
        ]);
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'text' => 'hi all',
        ]);

        $seenByAll = function () use ($admin, $group, $msg) {
            $row = collect(
                $this->actingAs($admin, 'api')
                    ->getJson("/api/auth/group/{$group->id}/messages")
                    ->json('data.messages')
            )->firstWhere('id', $msg->id);

            return $row['seen_by_all'];
        };

        $this->assertFalse($seenByAll(), 'nobody read yet');

        // One of two other members reads → still not "all".
        $this->actingAs($member, 'api')->postJson("/api/auth/group/{$group->id}/read")->assertOk();
        $this->assertFalse($seenByAll(), 'only one of two read');

        // Both other members have now read → seen_by_all flips true.
        $this->actingAs($member2, 'api')->postJson("/api/auth/group/{$group->id}/read")->assertOk();
        $this->assertTrue($seenByAll(), 'everyone read');
    }

    /**
     * `seen_by_others` on a reaction drives the sender's "watched" dot and is
     * true only once the ORIGINAL media sender has viewed it — a view by any
     * other member leaves it false (the false-green fix).
     */
    #[Test]
    public function get_messages_reports_seen_by_others_only_when_media_sender_viewed(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $member2 = User::factory()->create();
        GroupMember::factory()->create(['group_id' => $group->id, 'user_id' => $member2->id]);

        // $member sent the media; $admin's reaction replies to it.
        $media = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $member->id,
            'text' => 'media',
        ]);
        $reaction = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'message_type' => 'reaction',
            'reply_to_message_id' => $media->id,
        ]);

        $find = fn ($resp) => collect($resp->json('data.messages'))
            ->firstWhere('id', $reaction->id);

        // Before anyone views it, the sender sees seen_by_others = false.
        $before = $find($this->actingAs($admin, 'api')
            ->getJson("/api/auth/group/{$group->id}/messages"));
        $this->assertNotNull($before);
        $this->assertFalse($before['seen_by_others']);

        // A NON-media-sender member views it → dot must stay grey.
        $this->actingAs($member2, 'api')
            ->postJson("/api/auth/group/mark-viewed/{$reaction->id}")->assertOk();
        $mid = $find($this->actingAs($admin, 'api')
            ->getJson("/api/auth/group/{$group->id}/messages"));
        $this->assertFalse($mid['seen_by_others'], 'a non-media-sender view must not green the dot');

        // The media sender views it → seen_by_others flips true.
        $this->actingAs($member, 'api')
            ->postJson("/api/auth/group/mark-viewed/{$reaction->id}")->assertOk();
        $after = $find($this->actingAs($admin, 'api')
            ->getJson("/api/auth/group/{$group->id}/messages"));
        $this->assertTrue($after['seen_by_others']);
    }

    // -------- mark as read --------

    /**
     * /read inserts a `group_message_reads` row per unread message.
     * Tests that one read row gets created against the seeded message.
     * This is what drives "X members read your message" indicators.
     */
    #[Test]
    public function mark_as_read_records_a_read_row(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
        ]);

        $resp = $this->actingAs($member, 'api')->postJson("/api/auth/group/{$group->id}/read");
        $resp->assertOk();

        $this->assertDatabaseHas('group_message_reads', [
            'group_message_id' => $msg->id,
            'user_id' => $member->id,
        ]);
    }

    /** Strangers can't claim "I read your message" → 403. */
    #[Test]
    public function mark_as_read_rejects_non_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $stranger = User::factory()->create();

        $resp = $this->actingAs($stranger, 'api')->postJson("/api/auth/group/{$group->id}/read");
        $resp->assertStatus(403);
    }

    // -------- mark viewed --------

    /**
     * Group mark-viewed is per-user: only group members can mark a
     * message as viewed (which flips THEIR own blur status). A
     * stranger trying to mark-viewed gets 403.
     */
    #[Test]
    public function mark_viewed_returns_403_for_non_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $stranger = User::factory()->create();
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
        ]);

        $resp = $this->actingAs($stranger, 'api')->postJson("/api/auth/group/mark-viewed/{$msg->id}");
        $resp->assertJsonPath('code', 403);
    }

    /** Unknown message id → code:404 in body. */
    #[Test]
    public function mark_viewed_returns_404_for_unknown_message(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $resp = $this->actingAs($admin, 'api')->postJson('/api/auth/group/mark-viewed/999999');
        $resp->assertJsonPath('code', 404);
    }

    // -------- delete messages --------

    /**
     * Admin can bulk-delete multiple messages at once — even messages
     * sent by other members. Both rows end up soft-deleted (the
     * GroupMessage model uses SoftDeletes). Authorial ownership doesn't
     * matter for admin deletes; the role does.
     */
    #[Test]
    public function delete_messages_admin_can_bulk_delete(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg1 = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
        ]);
        $msg2 = GroupMessage::factory()->create([
            'group_id' => $group->id,
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

    /**
     * Regular members CAN'T bulk-delete, even if the message belongs
     * to them. (Individual self-message deletion is a different
     * endpoint.) → 403.
     */
    #[Test]
    public function delete_messages_rejects_non_admin(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $msg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
        ]);

        $resp = $this->actingAs($member, 'api')->deleteJson(
            "/api/auth/group/{$group->id}/delete-messages",
            ['message_ids' => [$msg->id]],
        );
        $resp->assertStatus(403);
    }

    /** `message_ids.*` must `exists:group_messages,id` → 422 on bogus ids. */
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

    // -------- message media --------

    /** No auth → 401. */
    #[Test]
    public function message_media_requires_auth(): void
    {
        $group = Group::factory()->create();
        $this->getJson("/api/auth/group/{$group->id}/messages/media")
            ->assertStatus(401);
    }

    /**
     * Happy path: a member fetches the group's shared-media gallery.
     * Only messages with a non-null `file` column are returned — a
     * text-only message is filtered out. This is a read-only query, so
     * no filesystem access is involved (the `file` value is just a
     * stored path string on the factory-created row).
     */
    #[Test]
    public function message_media_returns_only_file_messages_for_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();

        $mediaMsg = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'file' => 'uploads/group_message/photo.jpg',
        ]);
        GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'text' => 'just text',
            'file' => null,
        ]);

        $resp = $this->actingAs($member, 'api')->getJson(
            "/api/auth/group/{$group->id}/messages/media"
        );
        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonPath('data.pagination.total', 1);

        $ids = collect($resp->json('data.media'))->pluck('id')->all();
        $this->assertContains($mediaMsg->id, $ids);
    }

    /** Unknown group id → 404. */
    #[Test]
    public function message_media_returns_404_for_unknown_group(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->getJson(
            '/api/auth/group/999999/messages/media'
        );
        $resp->assertStatus(404);
    }

    /** Strangers cannot browse a group's media gallery → 403. */
    #[Test]
    public function message_media_returns_403_for_non_members(): void
    {
        [$admin, $member, $group] = $this->makeGroupWithMember();
        $stranger = User::factory()->create();

        $resp = $this->actingAs($stranger, 'api')->getJson(
            "/api/auth/group/{$group->id}/messages/media"
        );
        $resp->assertStatus(403);
    }
}
