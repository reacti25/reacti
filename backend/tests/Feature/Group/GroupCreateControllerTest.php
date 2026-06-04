<?php

namespace Tests\Feature\Group;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
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

    /** No auth → 401. */
    #[Test]
    public function create_group_requires_auth(): void
    {
        $member = User::factory()->create();
        $this->postJson('/api/auth/group/create', [
            'name' => 'X',
            'members' => [$member->id],
        ])->assertStatus(401);
    }

    /**
     * Happy path. The creator is auto-promoted to admin via a
     * `group_members` row with role='admin'; the supplied members are
     * added with role='member'. Asserting all three rows guards against
     * a regression that creates the group without promoting its
     * creator (which would leave the group without an admin).
     */
    #[Test]
    public function create_group_persists_a_group_and_members(): void
    {
        $admin = User::factory()->create();
        $alice = User::factory()->create();
        $bob = User::factory()->create();

        $resp = $this->actingAs($admin, 'api')->postJson('/api/auth/group/create', [
            'name' => 'Patent Team',
            'description' => 'load-bearing',
            'members' => [$alice->id, $bob->id],
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('success', true);

        $this->assertDatabaseHas('groups', [
            'name' => 'Patent Team',
            'created_by' => $admin->id,
        ]);

        $group = Group::where('created_by', $admin->id)->first();
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id' => $admin->id,
            'role' => 'admin',
        ]);
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id' => $alice->id,
            'role' => 'member',
        ]);
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id,
            'user_id' => $bob->id,
        ]);
    }

    /** `name` is required per the validator. Missing → 422. */
    #[Test]
    public function create_group_validates_required_name(): void
    {
        $user = User::factory()->create();
        $member = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/auth/group/create', [
            'members' => [$member->id],
        ]);

        $resp->assertStatus(422);
    }

    /** `members.*` must `exists:users,id` → 422 on a bogus member id. */
    #[Test]
    public function create_group_validates_members_existence(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/auth/group/create', [
            'name' => 'X',
            'members' => [999999],
        ]);

        $resp->assertStatus(422);
    }

    // -------- list --------

    /** No auth → 401. */
    #[Test]
    public function list_groups_requires_auth(): void
    {
        $this->getJson('/api/auth/group/list')->assertStatus(401);
    }

    /**
     * /list is scoped to "groups I'm a member of". Seeded one group I
     * belong to + one belonging to someone else; only mine appears.
     * Otherwise anyone could enumerate all groups in the system.
     */
    #[Test]
    public function list_groups_returns_groups_the_user_belongs_to(): void
    {
        $me = User::factory()->create();
        $other = User::factory()->create();
        $myGroup = Group::factory()->create(['created_by' => $me->id]);
        $otherGroup = Group::factory()->create(['created_by' => $other->id]);

        GroupMember::factory()->admin()->create([
            'group_id' => $myGroup->id,
            'user_id' => $me->id,
        ]);
        GroupMember::factory()->admin()->create([
            'group_id' => $otherGroup->id,
            'user_id' => $other->id,
        ]);

        $resp = $this->actingAs($me, 'api')->getJson('/api/auth/group/list');
        $resp->assertOk();

        $ids = collect($resp->json('groups'))->pluck('id')->all();
        $this->assertContains($myGroup->id, $ids);
        $this->assertNotContains($otherGroup->id, $ids);
    }

    // -------- details --------

    /** No auth → 401. */
    #[Test]
    public function group_details_requires_auth(): void
    {
        $g = Group::factory()->create();
        $this->getJson("/api/auth/group/{$g->id}")->assertStatus(401);
    }

    /** Unknown group id → 404. */
    #[Test]
    public function group_details_returns_404_for_unknown_group(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->getJson('/api/auth/group/999999');
        $resp->assertStatus(404);
    }

    /**
     * Non-members get 403, NOT 404. The distinction matters: 404 would
     * hide the existence of the group, but the controller chose to
     * acknowledge it exists and reject. Pinning this so a future
     * change to 404 is intentional, not accidental.
     */
    #[Test]
    public function group_details_returns_403_for_non_members(): void
    {
        $stranger = User::factory()->create();
        $owner = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $owner->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $owner->id,
        ]);

        $resp = $this->actingAs($stranger, 'api')->getJson("/api/auth/group/{$group->id}");
        $resp->assertStatus(403);
    }

    /**
     * Members get the full group payload back. We assert
     * `data.group.id` matches so a future refactor that changes the
     * envelope shape is caught.
     */
    #[Test]
    public function group_details_returns_data_for_members(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $admin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->getJson("/api/auth/group/{$group->id}");
        $resp->assertOk();
        $resp->assertJsonPath('data.group.id', $group->id);
    }

    // -------- update group --------

    /** No auth → 401. */
    #[Test]
    public function update_group_requires_auth(): void
    {
        $group = Group::factory()->create();
        $this->postJson("/api/auth/group/{$group->id}/update", ['name' => 'X'])
            ->assertStatus(401);
    }

    /**
     * Happy path: an admin updates the name and description. Both
     * `groups` columns change. No avatar is sent, so the controller
     * never touches the filesystem (Helper::fileUpload writes to a
     * real `public_path`, so the avatar happy path is deliberately
     * not exercised here — only validation of it is, below).
     */
    #[Test]
    public function update_group_admin_can_update_name_and_description(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->create([
            'created_by' => $admin->id,
            'name' => 'Old name',
            'description' => 'Old description',
        ]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $admin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/update",
            [
                'name' => 'New name',
                'description' => 'New description',
            ],
        );

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertDatabaseHas('groups', [
            'id' => $group->id,
            'name' => 'New name',
            'description' => 'New description',
        ]);
    }

    /** Unknown group id → 404 (an empty body passes the all-nullable validator). */
    #[Test]
    public function update_group_returns_404_for_unknown_group(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->postJson(
            '/api/auth/group/999999/update',
            ['name' => 'X'],
        );
        $resp->assertStatus(404);
    }

    /**
     * Update is admin-only. A regular member is rejected with 403 and
     * the group is left untouched. Otherwise any member could rename
     * the group out from under the admins.
     */
    #[Test]
    public function update_group_returns_403_for_non_admin(): void
    {
        $admin = User::factory()->create();
        $regular = User::factory()->create();
        $group = Group::factory()->create([
            'created_by' => $admin->id,
            'name' => 'Untouched',
        ]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $admin->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id' => $regular->id,
        ]);

        $resp = $this->actingAs($regular, 'api')->postJson(
            "/api/auth/group/{$group->id}/update",
            ['name' => 'Hijacked'],
        );

        $resp->assertStatus(403);
        $this->assertDatabaseHas('groups', [
            'id' => $group->id,
            'name' => 'Untouched',
        ]);
    }

    /** `name` must be <= 255 chars per the validator → 422. */
    #[Test]
    public function update_group_validates_name_max_length(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $admin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/update",
            ['name' => str_repeat('a', 256)],
        );
        $resp->assertStatus(422);
    }

    /**
     * On `updateGroup` the `avatar` rule is `nullable|image|max:5120`.
     * A non-image upload fails the `image` rule → 422. This pins the
     * validation branch without needing a real image write.
     */
    #[Test]
    public function update_group_validates_avatar_must_be_image(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $admin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->post(
            "/api/auth/group/{$group->id}/update",
            ['avatar' => UploadedFile::fake()->create('not-an-image.pdf', 10)],
        );
        $resp->assertStatus(422);
    }

    // -------- update avatar --------

    /** No auth → 401. */
    #[Test]
    public function update_avatar_requires_auth(): void
    {
        $group = Group::factory()->create();
        $this->postJson("/api/auth/group/{$group->id}/update/avatar", [])
            ->assertStatus(401);
    }

    /**
     * `avatar` is `required` per the updateAvatar validator. A request
     * with no avatar fails validation → 422 (the controller returns the
     * error envelope with code:422).
     */
    #[Test]
    public function update_avatar_validates_avatar_required(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $admin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/update/avatar",
            [],
        );
        $resp->assertStatus(422);
    }

    /**
     * Unknown group id → 404. The `avatar` field must still be present
     * to clear the `required` validator before the 404 check is reached,
     * so a fake file is supplied (no real write happens — the group is
     * missing, so the controller bails before touching Helper).
     */
    #[Test]
    public function update_avatar_returns_404_for_unknown_group(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->post(
            '/api/auth/group/999999/update/avatar',
            ['avatar' => UploadedFile::fake()->image('avatar.jpg')],
        );
        $resp->assertStatus(404);
    }

    /**
     * Avatar update is admin-only. A regular member is rejected with
     * 403 before any upload happens (the controller checks isAdmin
     * before reading the file, so no real write occurs).
     */
    #[Test]
    public function update_avatar_returns_403_for_non_admin(): void
    {
        $admin = User::factory()->create();
        $regular = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $admin->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id' => $regular->id,
        ]);

        $resp = $this->actingAs($regular, 'api')->post(
            "/api/auth/group/{$group->id}/update/avatar",
            ['avatar' => UploadedFile::fake()->image('avatar.jpg')],
        );
        $resp->assertStatus(403);
    }
}
