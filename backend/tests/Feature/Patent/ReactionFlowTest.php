<?php

namespace Tests\Feature\Patent;

use App\Models\Chat;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Patent flow regression test.
 *
 * Locks the entire automatic-reaction-on-message-open loop:
 *
 *   1. Sender (A) sends a media message to receiver (B) -> server stores it as
 *      message_type=normal AND is_blurred=true.
 *   2. Receiver (B) opens the message -> client calls mark-viewed.
 *      Server flips is_blurred=false, is_viewed=true.
 *   3. Receiver's client silently records a 4-second front-camera video and
 *      uploads it back -> server stores message_type=reaction with
 *      reply_to_id pointing to the original message.
 *   4. The reaction record chains back to the original via reply_to_id.
 *
 * If any of these break, this test must fail. Do not weaken it.
 */
class ReactionFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    #[Test]
    public function it_locks_the_full_patent_flow(): void
    {
        $alice = User::factory()->create(['first_name' => 'Alice']);
        $bob   = User::factory()->create(['first_name' => 'Bob']);

        // -------- Step 1: Alice sends a media message to Bob --------
        $imageFile = UploadedFile::fake()->image('photo.jpg', 800, 600);

        $sendResp = $this->actingAs($alice, 'api')->post(
            "/api/auth/chat/send/{$bob->id}",
            [
                'text'         => '',
                'message_type' => 'normal',
                'file'         => $imageFile,
            ],
            ['Accept' => 'application/json']
        );

        $sendResp->assertOk();
        $sendResp->assertJsonPath('success', true);

        $messageId = $sendResp->json('data.chat.id');
        $this->assertNotNull($messageId, 'Send response must include data.chat.id');

        $this->assertDatabaseHas('chats', [
            'id'           => $messageId,
            'sender_id'    => $alice->id,
            'receiver_id'  => $bob->id,
            'message_type' => 'normal',
            'is_blurred'   => 1,
            'is_viewed'    => 0,
        ]);

        // -------- Step 2: Bob opens the message (mark-viewed) --------
        $viewResp = $this->actingAs($bob, 'api')->postJson(
            "/api/auth/chat/mark-viewed/{$messageId}"
        );

        $viewResp->assertOk();
        $viewResp->assertJsonPath('success', true);

        $this->assertDatabaseHas('chats', [
            'id'         => $messageId,
            'is_blurred' => 0,
            'is_viewed'  => 1,
        ]);

        // -------- Step 3: Bob's client silently uploads the reaction --------
        $reactionVideo = UploadedFile::fake()->create('reaction.mp4', 200, 'video/mp4');

        $reactResp = $this->actingAs($bob, 'api')->post(
            "/api/auth/chat/send/{$alice->id}",
            [
                'text'         => '',
                'message_type' => 'reaction',
                'reply_to_id'  => (string) $messageId,
                'file'         => $reactionVideo,
            ],
            ['Accept' => 'application/json']
        );

        $reactResp->assertOk();
        $reactResp->assertJsonPath('success', true);

        $reactionId = $reactResp->json('data.chat.id');
        $this->assertNotNull($reactionId, 'Reaction response must include data.chat.id');

        $this->assertDatabaseHas('chats', [
            'id'           => $reactionId,
            'sender_id'    => $bob->id,
            'receiver_id'  => $alice->id,
            'message_type' => 'reaction',
            'reply_to_id'  => $messageId,
        ]);

        // -------- Step 4: The reaction chains back to the original --------
        $reaction = Chat::find($reactionId);
        $this->assertSame((int) $messageId, (int) $reaction->reply_to_id);
        $this->assertSame('reaction', $reaction->message_type);
    }
}
