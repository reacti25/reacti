<?php

namespace Database\Factories;

use App\Models\Group;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds Group rows. `created_by` auto-creates a User; override to
 * use a specific creator. Membership is NOT auto-seeded — combine
 * with GroupMemberFactory to add admins/members:
 *
 *   $group = Group::factory()->create(['created_by' => $admin->id]);
 *   GroupMember::factory()->admin()->create([
 *       'group_id' => $group->id,
 *       'user_id'  => $admin->id,
 *   ]);
 *
 * The creator is the owner (Group::isOwner()) but does not automatically
 * hold the 'admin' role in group_members — that's a separate row.
 */
class GroupFactory extends Factory
{
    protected $model = Group::class;

    public function definition(): array
    {
        return [
            'name' => $this->faker->words(3, true),
            'description' => $this->faker->sentence(),
            'avatar' => null,
            'created_by' => User::factory(),
        ];
    }
}
