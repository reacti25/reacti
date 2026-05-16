<?php

namespace Tests\Unit\Models;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pure-logic tests for the Group model's membership predicates.
 *
 *   isMember($userId)  — does this user have a row in group_members
 *   isAdmin($userId)   — same, but role='admin'
 *   isOwner($userId)   — created_by matches
 *
 * Controllers gate group-mutation endpoints on these — the
 * GroupCreate/Message/ManageMember controllers all early-return 403
 * if !isAdmin and 404 if !isMember. A bug here propagates immediately
 * into all those surfaces.
 */
class GroupTest extends TestCase
{
    use RefreshDatabase;

    /** `isMember` is true for any user with a `group_members` row and false for outsiders. */
    #[Test]
    public function is_member_returns_true_for_members_only(): void
    {
        $admin   = User::factory()->create();
        $member  = User::factory()->create();
        $outsider = User::factory()->create();

        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $member->id,
        ]);

        $this->assertTrue($group->isMember($admin->id));
        $this->assertTrue($group->isMember($member->id));
        $this->assertFalse($group->isMember($outsider->id));
    }

    /** `isAdmin` is true only for members whose `group_members` role is `admin`. */
    #[Test]
    public function is_admin_returns_true_only_for_admin_role(): void
    {
        $admin   = User::factory()->create();
        $member  = User::factory()->create();

        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $member->id,
        ]);

        $this->assertTrue($group->isAdmin($admin->id));
        $this->assertFalse($group->isAdmin($member->id));
    }

    /** `isOwner` is true only for the user recorded in the group's `created_by` column. */
    #[Test]
    public function is_owner_returns_true_only_for_creator(): void
    {
        $creator = User::factory()->create();
        $other   = User::factory()->create();
        $group   = Group::factory()->create(['created_by' => $creator->id]);

        $this->assertTrue($group->isOwner($creator->id));
        $this->assertFalse($group->isOwner($other->id));
    }

    /** The `admins` relationship returns only the members whose role is `admin`, excluding plain members. */
    #[Test]
    public function admins_relationship_returns_only_admin_role_members(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $carol = User::factory()->create();

        $group = Group::factory()->create(['created_by' => $alice->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $alice->id,
        ]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $bob->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $carol->id,
        ]);

        $adminIds = $group->admins()->pluck('user_id')->all();

        $this->assertEqualsCanonicalizing([$alice->id, $bob->id], $adminIds);
    }
}
