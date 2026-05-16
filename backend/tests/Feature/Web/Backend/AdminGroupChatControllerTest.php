<?php

namespace Tests\Feature\Web\Backend;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * AdminGroupChatController — the group-chat surface of the admin
 * panel, mounted under `/admin/group/*` (see routes/backend.php).
 *
 * The controller resolves the current user with
 * `Auth::guard('web')->user()`, which `actingAs($admin)` satisfies
 * (actingAs defaults to the web guard).
 *
 * Permission model exercised here:
 *   - membership   → groupDetails, sendMessage, getMessages, markAsRead
 *   - admin role   → updateGroup
 *   - creator only → leaveGroup is *blocked* for the creator;
 *                     deleteGroup is *allowed* only for the creator
 *
 * Admin-middleware behavior is covered once by [[AdminMiddlewareTest]].
 *
 * Five routes in this group (`editMessage`, `addMembers`,
 * `removeMember`, `makeAdmin`, `deleteMessages`) point at controller
 * methods that don't exist — see the final test.
 */
class AdminGroupChatControllerTest extends TestCase
{
    use RefreshDatabase;

    /** `backend.app` pulls in @vite; stub it for the view test. */
    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    /**
     * Create and return a freshly persisted user with the `admin` role.
     *
     * Used to authenticate requests against the admin-guarded `/admin/*`
     * routes exercised by these tests.
     *
     * @return User A persisted admin-role user.
     */
    private function admin(): User
    {
        return User::factory()->create(['role' => 'admin']);
    }

    /**
     * Seeds a group owned by $creator, with $creator as an admin-role
     * member. Extra members can be attached afterwards.
     */
    private function groupOwnedBy(User $creator): Group
    {
        $group = Group::factory()->create(['created_by' => $creator->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $creator->id,
        ]);

        return $group;
    }

    /** `index` renders the `backend.layouts.chat.group_chat` Blade view. */
    #[Test]
    public function index_renders_the_group_chat_view(): void
    {
        $this->actingAs($this->admin())->get('/admin/group/chat')
            ->assertOk()
            ->assertViewIs('backend.layouts.chat.group_chat');
    }

    /** `getUsersList` returns every user as group-member candidates except the acting admin. */
    #[Test]
    public function get_users_list_returns_all_users_except_self(): void
    {
        $admin = $this->admin();
        $other = User::factory()->create();

        $resp = $this->actingAs($admin)->getJson('/admin/group/users/list');

        $resp->assertOk()->assertJsonPath('success', true);
        $ids = collect($resp->json('users'))->pluck('id')->all();
        $this->assertContains($other->id, $ids);
        $this->assertNotContains($admin->id, $ids);
    }

    /**
     * Creating a group persists the Group, makes the creator an
     * admin-role member, and adds each requested member with the
     * `member` role.
     */
    #[Test]
    public function create_group_persists_group_and_members(): void
    {
        $admin    = $this->admin();
        $alice    = User::factory()->create();
        $bob      = User::factory()->create();

        $resp = $this->actingAs($admin)->postJson('/admin/group/create', [
            'name'    => 'Release Crew',
            'members' => [$alice->id, $bob->id],
        ]);

        $resp->assertOk()->assertJsonPath('success', true);

        $this->assertDatabaseHas('groups', [
            'name'       => 'Release Crew',
            'created_by' => $admin->id,
        ]);
        $group = Group::where('name', 'Release Crew')->firstOrFail();

        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id'  => $admin->id,
            'role'     => 'admin',
        ]);
        foreach ([$alice, $bob] as $member) {
            $this->assertDatabaseHas('group_members', [
                'group_id' => $group->id,
                'user_id'  => $member->id,
                'role'     => 'member',
            ]);
        }
    }

    /** Missing `name` (and `members`) fails validation with 422. */
    #[Test]
    public function create_group_requires_name_and_members(): void
    {
        $this->actingAs($this->admin())->postJson('/admin/group/create', [])
            ->assertStatus(422);

        $this->assertDatabaseCount('groups', 0);
    }

    /** `listGroups` returns only groups the admin is a member of. */
    #[Test]
    public function list_groups_returns_only_groups_the_admin_belongs_to(): void
    {
        $admin = $this->admin();
        $mine  = $this->groupOwnedBy($admin);

        // A group the admin has nothing to do with.
        $this->groupOwnedBy(User::factory()->create());

        $resp = $this->actingAs($admin)->getJson('/admin/group/list');

        $resp->assertOk()->assertJsonPath('success', true);
        $ids = collect($resp->json('groups'))->pluck('id')->all();
        $this->assertContains($mine->id, $ids);
        $this->assertCount(1, $ids, 'Only the admin\'s own group should be listed.');
    }

    /** `groupDetails` for a non-existent group id → 404. */
    #[Test]
    public function group_details_returns_404_for_a_missing_group(): void
    {
        $this->actingAs($this->admin())->getJson('/admin/group/999999')
            ->assertStatus(404);
    }

    /** `groupDetails` for a group the admin does not belong to → 403. */
    #[Test]
    public function group_details_returns_403_when_the_admin_is_not_a_member(): void
    {
        $group = $this->groupOwnedBy(User::factory()->create());

        $this->actingAs($this->admin())->getJson("/admin/group/{$group->id}")
            ->assertStatus(403);
    }

    /** `groupDetails` for a group the admin is a member of → 200 with `success: true`. */
    #[Test]
    public function group_details_succeeds_for_a_member(): void
    {
        $admin = $this->admin();
        $group = $this->groupOwnedBy($admin);

        $this->actingAs($admin)->getJson("/admin/group/{$group->id}")
            ->assertOk()
            ->assertJsonPath('success', true);
    }

    /** `sendMessage` from a member persists a `group_messages` row for the group and sender. */
    #[Test]
    public function send_message_persists_a_group_message(): void
    {
        $admin = $this->admin();
        $group = $this->groupOwnedBy($admin);

        $resp = $this->actingAs($admin)->postJson("/admin/group/{$group->id}/send", [
            'text' => 'Standup in five',
        ]);

        $resp->assertOk()->assertJsonPath('success', true);
        $this->assertDatabaseHas('group_messages', [
            'group_id'  => $group->id,
            'sender_id' => $admin->id,
            'text'      => 'Standup in five',
        ]);
    }

    /** `sendMessage` from a non-member → 403 and no `group_messages` row is created. */
    #[Test]
    public function send_message_returns_403_for_a_non_member(): void
    {
        $group = $this->groupOwnedBy(User::factory()->create());

        $this->actingAs($this->admin())->postJson("/admin/group/{$group->id}/send", [
            'text' => 'let me in',
        ])->assertStatus(403);

        $this->assertDatabaseCount('group_messages', 0);
    }

    /** `sendMessage` to a non-existent group id → 404. */
    #[Test]
    public function send_message_returns_404_for_a_missing_group(): void
    {
        $this->actingAs($this->admin())->postJson('/admin/group/999999/send', [
            'text' => 'nobody home',
        ])->assertStatus(404);
    }

    /** `getMessages` returns the group's message thread (here two seeded messages). */
    #[Test]
    public function get_messages_returns_the_group_thread(): void
    {
        $admin = $this->admin();
        $group = $this->groupOwnedBy($admin);
        GroupMessage::factory()->count(2)->create([
            'group_id'  => $group->id,
            'sender_id' => $admin->id,
        ]);

        $resp = $this->actingAs($admin)->getJson("/admin/group/{$group->id}/messages");

        $resp->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonCount(2, 'data.messages');
    }

    /**
     * `markAsRead` creates a GroupMessageRead receipt for every unread
     * message the admin did not send themselves.
     */
    #[Test]
    public function mark_as_read_creates_read_receipts_for_incoming_messages(): void
    {
        $admin  = $this->admin();
        $sender = User::factory()->create();
        $group  = $this->groupOwnedBy($admin);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $sender->id,
        ]);

        $message = GroupMessage::factory()->create([
            'group_id'  => $group->id,
            'sender_id' => $sender->id,
        ]);

        $this->actingAs($admin)->postJson("/admin/group/{$group->id}/read")
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertDatabaseHas('group_message_reads', [
            'group_message_id' => $message->id,
            'user_id'          => $admin->id,
        ]);
    }

    /** `updateGroup` by an admin-role member renames the group and persists the change. */
    #[Test]
    public function update_group_changes_the_name_for_an_admin(): void
    {
        $admin = $this->admin();
        $group = $this->groupOwnedBy($admin); // creator is seeded as admin-role member

        $this->actingAs($admin)->postJson("/admin/group/{$group->id}/update", [
            'name' => 'Renamed Crew',
        ])->assertOk()->assertJsonPath('success', true);

        $this->assertDatabaseHas('groups', [
            'id'   => $group->id,
            'name' => 'Renamed Crew',
        ]);
    }

    /**
     * A plain member (no admin role) cannot rename the group. The
     * admin user here is only a `member` of someone else's group.
     */
    #[Test]
    public function update_group_returns_403_for_a_non_admin_member(): void
    {
        $admin = $this->admin();
        $group = $this->groupOwnedBy(User::factory()->create());
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $admin->id, // role => member
        ]);

        $this->actingAs($admin)->postJson("/admin/group/{$group->id}/update", [
            'name' => 'Hijacked',
        ])->assertStatus(403);
    }

    /** A non-creator member can leave; their membership row is removed. */
    #[Test]
    public function leave_group_removes_membership_for_a_non_creator(): void
    {
        $admin = $this->admin();
        $group = $this->groupOwnedBy(User::factory()->create());
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);

        $this->actingAs($admin)->postJson("/admin/group/{$group->id}/leave")
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertDatabaseMissing('group_members', [
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);
    }

    /** The creator cannot leave their own group — they must delete it. */
    #[Test]
    public function leave_group_is_blocked_for_the_creator(): void
    {
        $admin = $this->admin();
        $group = $this->groupOwnedBy($admin);

        $this->actingAs($admin)->postJson("/admin/group/{$group->id}/leave")
            ->assertStatus(403);

        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);
    }

    /**
     * `Group` uses SoftDeletes, so `deleteGroup` sets `deleted_at`
     * rather than removing the row — assert the soft-delete, not
     * absence.
     */
    #[Test]
    public function delete_group_soft_deletes_it_for_the_creator(): void
    {
        $admin = $this->admin();
        $group = $this->groupOwnedBy($admin);

        $this->actingAs($admin)->deleteJson("/admin/group/{$group->id}/delete")
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertSoftDeleted('groups', ['id' => $group->id]);
    }

    /** `deleteGroup` by a non-creator member → 403 and the group row is left intact. */
    #[Test]
    public function delete_group_returns_403_for_a_non_creator(): void
    {
        $admin = $this->admin();
        $group = $this->groupOwnedBy(User::factory()->create());
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);

        $this->actingAs($admin)->deleteJson("/admin/group/{$group->id}/delete")
            ->assertStatus(403);

        $this->assertDatabaseHas('groups', ['id' => $group->id]);
    }

    /**
     * KNOWN BUG (documented, not fixed — testing-only scope).
     *
     * routes/backend.php wires five routes to controller methods that
     * AdminGroupChatController never defines:
     *   POST   /admin/group/{id}/message/{messageId}  -> editMessage
     *   POST   /admin/group/{id}/add-members          -> addMembers
     *   DELETE /admin/group/{id}/remove-member/{uid}  -> removeMember
     *   POST   /admin/group/{id}/make-admin/{uid}     -> makeAdmin
     *   DELETE /admin/group/{id}/delete-messages      -> deleteMessages
     *
     * Hitting any of them dispatches to a missing method, so the base
     * controller throws BadMethodCallException → HTTP 500. `add-members`
     * is used as the probe. If these methods are implemented later this
     * test will start failing and should be replaced with real
     * per-endpoint coverage. Flagged in inventory.md §8.
     */
    #[Test]
    public function routes_to_unimplemented_methods_error_out(): void
    {
        $admin = $this->admin();
        $group = $this->groupOwnedBy($admin);

        $resp = $this->actingAs($admin)->postJson("/admin/group/{$group->id}/add-members", [
            'members' => [User::factory()->create()->id],
        ]);

        $this->assertGreaterThanOrEqual(
            500,
            $resp->status(),
            'add-members now resolves — implement real coverage for the five group-management routes.',
        );
    }
}
