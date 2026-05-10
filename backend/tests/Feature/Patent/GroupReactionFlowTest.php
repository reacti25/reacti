<?php

namespace Tests\Feature\Patent;

use App\Events\GroupMessageSendEvent;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Group-chat counterpart to ReactionFlowTest.
 *
 *   1. Alice (admin) sends a media message to the group.
 *      Server stores a GroupMessage row + a GroupMessageUserStatus row
 *      per member: sender unblurred, recipients blurred.
 *   2. Bob (member) calls mark-viewed.
 *      Server flips Bob's status row to is_viewed=true / is_blurred=false.
 *      The other member's row is untouched.
 *   3. Bob's client uploads the silent reaction back to the group.
 *      Server stores another GroupMessage with message_type=reaction
 *      and reply_to_message_id chaining back to the original.
 *
 * If any of these break, this test must fail.
 */
class GroupReactionFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    #[Test]
    public function it_locks_the_full_group_patent_flow(): void
    {
        Event::fake([GroupMessageSendEvent::class]);

        $alice = User::factory()->create(['first_name' => 'Alice']);
        $bob   = User::factory()->create(['first_name' => 'Bob']);
        $carol = User::factory()->create(['first_name' => 'Carol']);

        $group = Group::factory()->create(['created_by' => $alice->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $alice->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $bob->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $carol->id,
        ]);

        // -------- Step 1: Alice sends a media message to the group --------
        $imageFile = UploadedFile::fake()->image('photo.jpg', 800, 600);

        $sendResp = $this->actingAs($alice, 'api')->post(
            "/api/auth/group/{$group->id}/send",
            [
                'text'         => '',
                'message_type' => 'normal',
                'file'         => $imageFile,
            ],
            ['Accept' => 'application/json']
        );

        $sendResp->assertOk();
        $sendResp->assertJsonPath('success', true);

        $messageId = (int) $sendResp->json('data.message.id');
        $this->assertNotNull($messageId, 'Group send must return data.message.id');

        $this->assertDatabaseHas('group_messages', [
            'id'           => $messageId,
            'group_id'     => $group->id,
            'sender_id'    => $alice->id,
            'message_type' => 'normal',
        ]);

        // Per-user status — sender unblurred, recipients blurred.
        $this->assertDatabaseHas('group_message_user_statuses', [
            'message_id' => $messageId,
            'user_id'    => $alice->id,
            'is_blurred' => 0,
            'is_viewed'  => 0,
        ]);
        $this->assertDatabaseHas('group_message_user_statuses', [
            'message_id' => $messageId,
            'user_id'    => $bob->id,
            'is_blurred' => 1,
            'is_viewed'  => 0,
        ]);
        $this->assertDatabaseHas('group_message_user_statuses', [
            'message_id' => $messageId,
            'user_id'    => $carol->id,
            'is_blurred' => 1,
            'is_viewed'  => 0,
        ]);

        Event::assertDispatched(
            GroupMessageSendEvent::class,
            fn (GroupMessageSendEvent $event): bool => (int) $event->message->id === $messageId,
        );

        // -------- Step 2: Bob opens the message (mark-viewed) --------
        $viewResp = $this->actingAs($bob, 'api')->postJson(
            "/api/auth/group/mark-viewed/{$messageId}"
        );

        $viewResp->assertOk();
        $viewResp->assertJsonPath('success', true);

        // Bob's row is now unblurred + viewed.
        $this->assertDatabaseHas('group_message_user_statuses', [
            'message_id' => $messageId,
            'user_id'    => $bob->id,
            'is_blurred' => 0,
            'is_viewed'  => 1,
        ]);
        // Carol's row is untouched — mark-viewed is per-user.
        $this->assertDatabaseHas('group_message_user_statuses', [
            'message_id' => $messageId,
            'user_id'    => $carol->id,
            'is_blurred' => 1,
            'is_viewed'  => 0,
        ]);

        // -------- Step 3: Bob's client uploads the silent reaction --------
        $reactionVideo = UploadedFile::fake()->create('reaction.mp4', 200, 'video/mp4');

        $reactResp = $this->actingAs($bob, 'api')->post(
            "/api/auth/group/{$group->id}/send",
            [
                'text'                 => '',
                'message_type'         => 'reaction',
                'reply_to_message_id'  => (string) $messageId,
                'file'                 => $reactionVideo,
            ],
            ['Accept' => 'application/json']
        );

        $reactResp->assertOk();
        $reactResp->assertJsonPath('success', true);

        $reactionId = (int) $reactResp->json('data.message.id');
        $this->assertNotNull($reactionId, 'Reaction send must return data.message.id');

        $this->assertDatabaseHas('group_messages', [
            'id'                  => $reactionId,
            'group_id'            => $group->id,
            'sender_id'           => $bob->id,
            'message_type'        => 'reaction',
            'reply_to_message_id' => $messageId,
        ]);

        // -------- Step 4: The reaction chains back via reply_to_message_id --------
        $reaction = GroupMessage::find($reactionId);
        $this->assertSame($messageId, (int) $reaction->reply_to_message_id);
        $this->assertSame('reaction', $reaction->message_type);
    }
}
