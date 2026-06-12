<?php

namespace Tests\Feature\Security;

use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * B4 — the `reply_to` validation rules are scoped so a user can only reply
 * to a message inside the room / group they are actually posting to.
 *
 * Previously `reply_to_id` (1:1) and `reply_to_message_id` (group) used an
 * unscoped `exists:` rule, so any message id in the table validated — letting
 * a caller attach a reply that references a conversation or group they are not
 * part of (an IDOR-adjacent reference leak). These tests prove an in-scope
 * reply still works and an out-of-scope reply is rejected with 422.
 */
class ScopedExistsRulesTest extends TestCase
{
    use RefreshDatabase;

    /** A 1:1 reply to a message in the SAME conversation is accepted. */
    #[Test]
    public function chat_reply_to_a_message_in_the_same_conversation_is_allowed(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = Room::factory()->between($a, $b)->create();
        $theirMessage = Chat::factory()->create([
            'sender_id' => $b->id,
            'receiver_id' => $a->id,
            'room_id' => $room->id,
        ]);

        $this->actingAs($a, 'api')
            ->postJson('/api/auth/chat/send/'.$b->id, [
                'text' => 'replying',
                'reply_to_id' => $theirMessage->id,
            ])
            ->assertOk();
    }

    /** A 1:1 reply to a message from a DIFFERENT conversation is rejected (422). */
    #[Test]
    public function chat_reply_to_a_message_outside_the_conversation_is_rejected(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();

        // A conversation between two unrelated users; its message id exists
        // but is not part of the A↔B room.
        $c = User::factory()->create();
        $d = User::factory()->create();
        $otherRoom = Room::factory()->between($c, $d)->create();
        $foreignMessage = Chat::factory()->create([
            'sender_id' => $c->id,
            'receiver_id' => $d->id,
            'room_id' => $otherRoom->id,
        ]);

        $this->actingAs($a, 'api')
            ->postJson('/api/auth/chat/send/'.$b->id, [
                'text' => 'sneaky reply',
                'reply_to_id' => $foreignMessage->id,
            ])
            ->assertStatus(422);
    }

    /** A group reply to a message in the SAME group is accepted. */
    #[Test]
    public function group_reply_to_a_message_in_the_same_group_is_allowed(): void
    {
        $user = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $user->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $user->id,
        ]);
        $message = GroupMessage::factory()->create(['group_id' => $group->id]);

        $this->actingAs($user, 'api')
            ->postJson('/api/auth/group/'.$group->id.'/send', [
                'text' => 'replying in group',
                'reply_to_message_id' => $message->id,
            ])
            ->assertOk();
    }

    /** A group reply to a message from a DIFFERENT group is rejected (422). */
    #[Test]
    public function group_reply_to_a_message_outside_the_group_is_rejected(): void
    {
        $user = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $user->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $user->id,
        ]);

        // A message that lives in some other group the user isn't posting to.
        $otherGroup = Group::factory()->create();
        $foreignMessage = GroupMessage::factory()->create(['group_id' => $otherGroup->id]);

        $this->actingAs($user, 'api')
            ->postJson('/api/auth/group/'.$group->id.'/send', [
                'text' => 'sneaky group reply',
                'reply_to_message_id' => $foreignMessage->id,
            ])
            ->assertStatus(422);
    }
}
