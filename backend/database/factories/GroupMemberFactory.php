<?php

namespace Database\Factories;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * GroupMember pivot rows. Default role is 'member' — use the
 * `admin()` state for admin role.
 *
 * Both group_id and user_id default to brand-new factories; you'll
 * almost always want to override at least one to attach the member
 * to an existing group.
 */
class GroupMemberFactory extends Factory
{
    protected $model = GroupMember::class;

    public function definition(): array
    {
        return [
            'group_id'  => Group::factory(),
            'user_id'   => User::factory(),
            'role'      => 'member',
            'joined_at' => now(),
        ];
    }

    public function admin(): static
    {
        return $this->state(fn () => ['role' => 'admin']);
    }
}
