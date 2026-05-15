<?php

namespace Tests\Feature\Group;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The full member-management surface for groups, covering both the
 * happy and permission paths for every endpoint:
 *
 *   add-members              admin only
 *   remove-member/{user}     admin only; cannot remove creator
 *   make-admin/{user}        admin only; target must be a member
 *   remove-admin/{user}      admin only; cannot demote creator
 *   leave                    any member except creator
 *   delete                   creator only
 *   available-users          excludes existing members
 *
 * The creator-protection rules are load-bearing — a creator who can
 * be removed or demoted leaves the group ownerless.
 *
 * Each test reuses `makeGroupWithAdmin()` for setup; the admin is
 * also the creator, so creator-protected paths are tested by passing
 * the admin's own user id where the controller looks at `created_by`.
 */
class GroupManageMemberTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Build a Group with the auth user as both creator AND admin.
     * Returns [user, group] so callers can `actingAs($user)` directly.
     */
    private function makeGroupWithAdmin(): array
    {
        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);
        return [$admin, $group];
    }

    // -------- add members --------

    /** Happy path: an admin adds a new user; row appears in group_members. */
    #[Test]
    public function add_members_admin_can_add_users(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $newbie = User::factory()->create();

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/add-members",
            ['members' => [$newbie->id]],
        );

        $resp->assertOk();
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id'  => $newbie->id,
        ]);
    }

    /**
     * Regular members (not admins) can't add users → 403. Otherwise
     * any member could backdoor friends in without an admin's sign-off.
     */
    #[Test]
    public function add_members_rejects_non_admin(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $regular = User::factory()->create();
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $regular->id,
        ]);
        $newbie = User::factory()->create();

        $resp = $this->actingAs($regular, 'api')->postJson(
            "/api/auth/group/{$group->id}/add-members",
            ['members' => [$newbie->id]],
        );
        $resp->assertStatus(403);
    }

    /** `members.*` must `exists:users,id` → 422 on a bogus id. */
    #[Test]
    public function add_members_validates_member_ids(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/add-members",
            ['members' => [999999]],
        );
        $resp->assertStatus(422);
    }

    /** No auth → 401. */
    #[Test]
    public function add_members_requires_auth(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $this->postJson("/api/auth/group/{$group->id}/add-members", ['members' => [1]])
            ->assertStatus(401);
    }

    // -------- remove member --------

    /** Happy path: admin removes a regular member; row is gone. */
    #[Test]
    public function remove_member_admin_can_remove_a_regular_member(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $regular = User::factory()->create();
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $regular->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->deleteJson(
            "/api/auth/group/{$group->id}/remove-member/{$regular->id}"
        );
        $resp->assertOk();
        $this->assertDatabaseMissing('group_members', [
            'group_id' => $group->id,
            'user_id'  => $regular->id,
        ]);
    }

    /**
     * Creator-protection guard. Even an admin (who IS the creator here)
     * can't remove the creator from their own group via this endpoint
     * → 403. Removing the creator would leave the group ownerless and
     * break the `delete-group` flow (creator-only).
     */
    #[Test]
    public function remove_member_cannot_remove_creator(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();

        $resp = $this->actingAs($admin, 'api')->deleteJson(
            "/api/auth/group/{$group->id}/remove-member/{$admin->id}"
        );
        $resp->assertStatus(403);
    }

    /** Regular member trying to kick someone else → 403. */
    #[Test]
    public function remove_member_returns_403_for_non_admin(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $regular = User::factory()->create();
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $regular->id,
        ]);
        $target = User::factory()->create();
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $target->id,
        ]);

        $resp = $this->actingAs($regular, 'api')->deleteJson(
            "/api/auth/group/{$group->id}/remove-member/{$target->id}"
        );
        $resp->assertStatus(403);
    }

    /** No auth → 401. */
    #[Test]
    public function remove_member_requires_auth(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $this->deleteJson("/api/auth/group/{$group->id}/remove-member/1")
            ->assertStatus(401);
    }

    // -------- make admin --------

    /** Happy path: admin promotes a regular member; role flips to 'admin'. */
    #[Test]
    public function make_admin_promotes_a_regular_member(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $regular = User::factory()->create();
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $regular->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/make-admin/{$regular->id}"
        );
        $resp->assertOk();
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id'  => $regular->id,
            'role'     => 'admin',
        ]);
    }

    /** Can't promote a non-member to admin → 404. */
    #[Test]
    public function make_admin_returns_404_when_target_not_a_member(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $outsider = User::factory()->create();

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/make-admin/{$outsider->id}"
        );
        $resp->assertStatus(404);
    }

    /**
     * Regular members can't promote others (or themselves) → 403.
     * Important: a member calling /make-admin/{me} would otherwise
     * be a trivial privilege-escalation path.
     */
    #[Test]
    public function make_admin_returns_403_for_non_admin_callers(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $regular = User::factory()->create();
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $regular->id,
        ]);

        $resp = $this->actingAs($regular, 'api')->postJson(
            "/api/auth/group/{$group->id}/make-admin/{$regular->id}"
        );
        $resp->assertStatus(403);
    }

    // -------- remove admin --------

    /**
     * Happy path: admin demotes another admin to plain member. Used to
     * undo a "make-admin" mistake.
     */
    #[Test]
    public function remove_admin_demotes_an_admin_to_member(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $secondAdmin = User::factory()->create();
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $secondAdmin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/remove-admin/{$secondAdmin->id}"
        );
        $resp->assertOk();
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id'  => $secondAdmin->id,
            'role'     => 'member',
        ]);
    }

    /**
     * Creator-protection mirror of `remove_member_cannot_remove_creator`.
     * The creator is always an admin and can't be demoted → 403.
     */
    #[Test]
    public function remove_admin_cannot_demote_the_owner(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/remove-admin/{$admin->id}"
        );
        $resp->assertStatus(403);
    }

    // -------- leave group --------

    /**
     * Happy path: a regular member walks out and their row is deleted.
     * Self-service — the user doesn't need admin permission to leave.
     */
    #[Test]
    public function leave_group_removes_the_membership(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $regular = User::factory()->create();
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $regular->id,
        ]);

        $resp = $this->actingAs($regular, 'api')->postJson(
            "/api/auth/group/{$group->id}/leave"
        );
        $resp->assertOk();
        $this->assertDatabaseMissing('group_members', [
            'group_id' => $group->id,
            'user_id'  => $regular->id,
        ]);
    }

    /**
     * Creator can't leave their own group → 403. The path forward
     * for a creator is to delete the group instead (next test).
     * Otherwise the group ends up admin-less and orphaned.
     */
    #[Test]
    public function leave_group_rejects_creator(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/leave"
        );
        $resp->assertStatus(403);
    }

    // -------- delete group --------

    /**
     * Creator can soft-delete the group. Soft-delete preserves the
     * row for audit / undelete; the `members.*` rows remain (an admin
     * action, e.g. via the Laravel admin, can restore).
     */
    #[Test]
    public function delete_group_only_works_for_creator(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();

        $resp = $this->actingAs($admin, 'api')->deleteJson(
            "/api/auth/group/{$group->id}/delete"
        );
        $resp->assertOk();
        $this->assertSoftDeleted('groups', ['id' => $group->id]);
    }

    /**
     * Even a non-creator ADMIN can't delete the group → 403. Strict
     * creator-only privilege. Stops a hostile admin from nuking the
     * group out from under the creator.
     */
    #[Test]
    public function delete_group_rejects_non_creator(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $secondAdmin = User::factory()->create();
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $secondAdmin->id,
        ]);

        $resp = $this->actingAs($secondAdmin, 'api')->deleteJson(
            "/api/auth/group/{$group->id}/delete"
        );
        $resp->assertStatus(403);
    }

    /** No auth → 401. */
    #[Test]
    public function delete_group_requires_auth(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $this->deleteJson("/api/auth/group/{$group->id}/delete")->assertStatus(401);
    }

    // -------- available users --------

    /**
     * /available-users powers the "add member" picker in the UI. It
     * lists all users in the system EXCEPT those already in the group
     * (we don't want to show admins users they can't add). Seeded one
     * existing member + one outsider; only the outsider appears.
     */
    #[Test]
    public function available_users_excludes_existing_members(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $member  = User::factory()->create();
        $outsider = User::factory()->create();
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $member->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->getJson(
            "/api/auth/group/{$group->id}/available-users"
        );
        $resp->assertOk();

        $ids = collect($resp->json('data.users'))->pluck('id')->all();
        $this->assertContains($outsider->id, $ids);
        $this->assertNotContains($member->id, $ids);
        $this->assertNotContains($admin->id, $ids);
    }
}
