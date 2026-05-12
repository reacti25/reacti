<?php

namespace Database\Factories;

use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * GroupMessage rows. Default is a text message (message_type=normal,
 * status=sent, no file). States:
 *
 *   withMedia()  — adds a fake image file
 *   reaction()   — message_type='reaction', file set, text cleared
 *
 * NOTE: GroupMessage does NOT carry blur/view state — that lives in
 * the `group_message_user_statuses` pivot, one row per (message, user)
 * pair. The send controller creates those rows in bulk for every
 * member. Tests that depend on per-user blur state need to seed
 * that pivot directly.
 */
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
