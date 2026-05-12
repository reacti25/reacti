<?php

namespace Database\Factories;

use App\Models\FriendRequest;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * FriendRequest rows for tests. Default state is `pending` — use the
 * `accepted()` / `declined()` states for terminal states.
 *
 * sender_id / receiver_id default to brand-new Users; override one or
 * both to seed a request between specific actors.
 */
class FriendRequestFactory extends Factory
{
    protected $model = FriendRequest::class;

    public function definition(): array
    {
        return [
            'sender_id'   => User::factory(),
            'receiver_id' => User::factory(),
            'status'      => 'pending',
            'accepted_at' => null,
        ];
    }

    public function accepted(): static
    {
        return $this->state(fn () => [
            'status'      => 'accepted',
            'accepted_at' => now(),
        ]);
    }

    public function declined(): static
    {
        return $this->state(fn () => [
            'status' => 'declined',
        ]);
    }
}
