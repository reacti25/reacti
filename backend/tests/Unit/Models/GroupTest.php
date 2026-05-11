<?php

namespace Tests\Unit\Models;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class GroupTest extends TestCase
{
    use RefreshDatabase;

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

    #[Test]
    public function is_owner_returns_true_only_for_creator(): void
    {
        $creator = User::factory()->create();
        $other   = User::factory()->create();
        $group   = Group::factory()->create(['created_by' => $creator->id]);

        $this->assertTrue($group->isOwner($creator->id));
        $this->assertFalse($group->isOwner($other->id));
    }

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
