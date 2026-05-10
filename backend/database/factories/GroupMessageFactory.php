<?php

namespace Database\Factories;

use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class GroupMessageFactory extends Factory
{
    protected $model = GroupMessage::class;

    public function definition(): array
    {
        return [
            'group_id'            => Group::factory(),
            'sender_id'           => User::factory(),
            'text'                => $this->faker->sentence(),
            'file'                => null,
            'status'              => 'sent',
            'message_type'        => 'normal',
            'reply_to_message_id' => null,
        ];
    }

    public function withMedia(): static
    {
        return $this->state(fn () => [
            'file' => 'fake/path/group-photo.jpg',
            'text' => null,
        ]);
    }

    public function reaction(): static
    {
        return $this->state(fn () => [
            'message_type' => 'reaction',
            'file'         => 'fake/path/reaction.mp4',
            'text'         => null,
        ]);
    }
}
