<?php

namespace Database\Factories;

use App\Models\Room;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class RoomFactory extends Factory
{
    protected $model = Room::class;

    public function definition(): array
    {
        $userOne = User::factory()->create();
        $userTwo = User::factory()->create();

        // Match the application convention: smaller user id always goes in user_one_id.
        $minId = min($userOne->id, $userTwo->id);
        $maxId = max($userOne->id, $userTwo->id);

        return [
            'user_one_id' => $minId,
            'user_two_id' => $maxId,
        ];
    }

    public function between(User $a, User $b): static
    {
        $minId = min($a->id, $b->id);
        $maxId = max($a->id, $b->id);

        return $this->state(fn () => [
            'user_one_id' => $minId,
            'user_two_id' => $maxId,
        ]);
    }
}
