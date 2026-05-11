<?php

namespace Tests\Feature\Group;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class GroupManageMemberTest extends TestCase
{
    use RefreshDatabase;

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

    #[Test]
    public function add_members_requires_auth(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $this->postJson("/api/auth/group/{$group->id}/add-members", ['members' => [1]])
            ->assertStatus(401);
    }

    // -------- remove member --------

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

    #[Test]
    public function remove_member_cannot_remove_creator(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();

        $resp = $this->actingAs($admin, 'api')->deleteJson(
            "/api/auth/group/{$group->id}/remove-member/{$admin->id}"
        );
        $resp->assertStatus(403);
    }

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

    #[Test]
    public function remove_member_requires_auth(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $this->deleteJson("/api/auth/group/{$group->id}/remove-member/1")
            ->assertStatus(401);
    }

    // -------- make admin --------

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

    #[Test]
    public function delete_group_requires_auth(): void
    {
        [$admin, $group] = $this->makeGroupWithAdmin();
        $this->deleteJson("/api/auth/group/{$group->id}/delete")->assertStatus(401);
    }

    // -------- available users --------

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
