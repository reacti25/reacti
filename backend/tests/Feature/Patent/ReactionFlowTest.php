<?php

namespace Tests\Feature\Patent;

use App\Models\Chat;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;
use Tymon\JWTAuth\Facades\JWTAuth;

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
 *   4. Sender's conversation now contains both messages, correctly linked.
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

    /** @test */
    public function it_locks_the_full_patent_flow(): void
    {
        // Two users: A is the sender, B is the receiver.
        $alice = User::factory()->create(['first_name' => 'Alice']);
        $bob   = User::factory()->create(['first_name' => 'Bob']);

        // -------- Step 1: Alice sends a media message to Bob --------
        $imageFile = UploadedFile::fake()->image('photo.jpg', 800, 600);

        $aliceToken = JWTAuth::fromUser($alice);

        $sendResp = $this->withHeader('Authorization', "Bearer {$aliceToken}")
            ->postJson("/api/auth/chat/send/{$bob->id}", [
                'text'         => '',
                'message_type' => 'normal',
            ], [
                'file' => $imageFile,
            ]);

        $sendResp->assertOk();
        $sendResp->assertJsonPath('success', true);

        $messageId = $sendResp->json('data.chat.id');
        $this->assertNotNull($messageId, 'Send response must include data.chat.id');

        $this->assertDatabaseHas('chats', [
            'id'           => $messageId,
            'sender_id'    => $alice->id,
            'receiver_id'  => $bob->id,
            'message_type' => 'normal',
            'is_blurred'   => true,
            'is_viewed'    => false,
        ]);

        // -------- Step 2: Bob opens the message (mark-viewed) --------
        $bobToken = JWTAuth::fromUser($bob);

        $viewResp = $this->withHeader('Authorization', "Bearer {$bobToken}")
            ->postJson("/api/auth/chat/mark-viewed/{$messageId}");

        $viewResp->assertOk();
        $viewResp->assertJsonPath('success', true);

        $this->assertDatabaseHas('chats', [
            'id'         => $messageId,
            'is_blurred' => false,
            'is_viewed'  => true,
        ]);

        // -------- Step 3: Bob's client silently uploads the reaction --------
        $reactionVideo = UploadedFile::fake()->create('reaction.mp4', 200, 'video/mp4');

        $reactResp = $this->withHeader('Authorization', "Bearer {$bobToken}")
            ->postJson("/api/auth/chat/send/{$alice->id}", [
                'text'         => '',
                'message_type' => 'reaction',
                'reply_to_id'  => $messageId,
            ], [
                'file' => $reactionVideo,
            ]);

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

        // -------- Step 4: Conversation links the original to the reaction --------
        $convResp = $this->withHeader('Authorization', "Bearer {$aliceToken}")
            ->getJson("/api/auth/chat/conversation/{$bob->id}");

        $convResp->assertOk();

        $messageIds = collect($convResp->json('data.chats') ?? $convResp->json('data') ?? [])
            ->pluck('id')
            ->all();

        $this->assertContains(
            $messageId,
            $messageIds,
            'Conversation must contain the original message.'
        );
        $this->assertContains(
            $reactionId,
            $messageIds,
            'Conversation must contain the reaction message.'
        );

        // The reaction's reply_to_id chains it to the original.
        $reaction = Chat::find($reactionId);
        $this->assertSame($messageId, (int) $reaction->reply_to_id);
        $this->assertSame('reaction', $reaction->message_type);
    }
}
