<?php

namespace Tests\Feature\Group;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Endpoint coverage for GroupCreateController. updateGroup and
 * updateAvatar are exercised end-to-end by GroupUpdatedEventTest;
 * this file covers create/list/details and the auth/validation paths.
 */
class GroupCreateControllerTest extends TestCase
{
    use RefreshDatabase;

    // -------- create --------

    #[Test]
    public function create_group_requires_auth(): void
    {
        $member = User::factory()->create();
        $this->postJson('/api/auth/group/create', [
            'name'    => 'X',
            'members' => [$member->id],
        ])->assertStatus(401);
    }

    #[Test]
    public function create_group_persists_a_group_and_members(): void
    {
        $admin   = User::factory()->create();
        $alice   = User::factory()->create();
        $bob     = User::factory()->create();

        $resp = $this->actingAs($admin, 'api')->postJson('/api/auth/group/create', [
            'name'        => 'Patent Team',
            'description' => 'load-bearing',
            'members'     => [$alice->id, $bob->id],
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('success', true);

        $this->assertDatabaseHas('groups', [
            'name'       => 'Patent Team',
            'created_by' => $admin->id,
        ]);

        $group = Group::where('created_by', $admin->id)->first();
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id'  => $admin->id,
            'role'     => 'admin',
        ]);
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id'  => $alice->id,
            'role'     => 'member',
        ]);
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id'  => $bob->id,
        ]);
    }

    #[Test]
    public function create_group_validates_required_name(): void
    {
        $user   = User::factory()->create();
        $member = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/auth/group/create', [
            'members' => [$member->id],
        ]);

        $resp->assertStatus(422);
    }

    #[Test]
    public function create_group_validates_members_existence(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/auth/group/create', [
            'name'    => 'X',
            'members' => [999999],
        ]);

        $resp->assertStatus(422);
    }

    // -------- list --------

    #[Test]
    public function list_groups_requires_auth(): void
    {
        $this->getJson('/api/auth/group/list')->assertStatus(401);
    }

    #[Test]
    public function list_groups_returns_groups_the_user_belongs_to(): void
    {
        $me        = User::factory()->create();
        $other     = User::factory()->create();
        $myGroup   = Group::factory()->create(['created_by' => $me->id]);
        $otherGroup = Group::factory()->create(['created_by' => $other->id]);

        GroupMember::factory()->admin()->create([
            'group_id' => $myGroup->id,
            'user_id'  => $me->id,
        ]);
        GroupMember::factory()->admin()->create([
            'group_id' => $otherGroup->id,
            'user_id'  => $other->id,
        ]);

        $resp = $this->actingAs($me, 'api')->getJson('/api/auth/group/list');
        $resp->assertOk();

        $ids = collect($resp->json('groups'))->pluck('id')->all();
        $this->assertContains($myGroup->id, $ids);
        $this->assertNotContains($otherGroup->id, $ids);
    }

    // -------- details --------

    #[Test]
    public function group_details_requires_auth(): void
    {
        $g = Group::factory()->create();
        $this->getJson("/api/auth/group/{$g->id}")->assertStatus(401);
    }

    #[Test]
    public function group_details_returns_404_for_unknown_group(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->getJson('/api/auth/group/999999');
        $resp->assertStatus(404);
    }

    #[Test]
    public function group_details_returns_403_for_non_members(): void
    {
        $stranger = User::factory()->create();
        $owner    = User::factory()->create();
        $group    = Group::factory()->create(['created_by' => $owner->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $owner->id,
        ]);

        $resp = $this->actingAs($stranger, 'api')->getJson("/api/auth/group/{$group->id}");
        $resp->assertStatus(403);
    }

    #[Test]
    public function group_details_returns_data_for_members(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->getJson("/api/auth/group/{$group->id}");
        $resp->assertOk();
        $resp->assertJsonPath('data.group.id', $group->id);
    }
}
