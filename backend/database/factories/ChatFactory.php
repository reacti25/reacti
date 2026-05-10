<?php

namespace Database\Factories;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class ChatFactory extends Factory
{
    protected $model = Chat::class;

    public function definition(): array
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();
        $room = Room::factory()->between($sender, $receiver)->create();

        return [
            'sender_id'    => $sender->id,
            'receiver_id'  => $receiver->id,
            'room_id'      => $room->id,
            'text'         => $this->faker->sentence(),
            'file'         => null,
            'file_type'    => null,
            'thumbnail'    => null,
            'status'       => 'sent',
            'message_type' => 'normal',
            'is_blurred'   => false,
            'is_viewed'    => false,
            'reply_to_id'  => null,
            'forwarded_from' => null,
        ];
    }

    public function blurredMedia(): static
    {
        return $this->state(fn () => [
            'file'         => 'fake/path/photo.jpg',
            'file_type'    => 'image',
            'message_type' => 'normal',
            'is_blurred'   => true,
            'is_viewed'    => false,
            'text'         => null,
        ]);
    }

    public function viewed(): static
    {
        return $this->state(fn () => [
            'is_blurred' => false,
            'is_viewed'  => true,
        ]);
    }

    public function reactionTo(Chat $original): static
    {
        return $this->state(fn () => [
            'sender_id'    => $original->receiver_id,
            'receiver_id'  => $original->sender_id,
            'room_id'      => $original->room_id,
            'message_type' => 'reaction',
            'reply_to_id'  => $original->id,
            'file'         => 'fake/path/reaction.mp4',
            'file_type'    => 'video',
            'text'         => null,
        ]);
    }
}
