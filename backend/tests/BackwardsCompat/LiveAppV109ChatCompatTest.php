<?php

namespace Tests\BackwardsCompat;

use App\Models\Chat;
use App\Models\Friend;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\Contract\Support\ContractMatcher;

/**
 * Backwards-compatibility tests: the live App Store app (v1.0.9) must still be
 * able to parse the candidate backend's private-chat responses (Plan A1).
 *
 * The private-chat path is where the 2026-05-23 incident happened, and it is
 * where the live app is strictest: its `inbox_response.dart` parses `is_viewed`
 * into a non-nullable-typed `int?`, so a JSON boolean there crashes the whole
 * conversation parse -> empty/black private chats. These tests hit the real
 * 1:1 endpoints and assert the responses satisfy the frozen v1.0.9 shapes.
 *
 * The group path is intentionally NOT guarded for `is_viewed`: the live app's
 * `group_inbox_response.dart` parses group `is_viewed` as `dynamic`, so it
 * tolerates int OR bool. Only the private path needs the integer guarantee.
 */
class LiveAppV109ChatCompatTest extends BackwardsCompatTestCase
{
    use RefreshDatabase;

    private User $userA;

    private User $userB;

    private Chat $media;

    /**
     * Build the same realistic 1:1 conversation the contract suite uses: A and
     * B are friends sharing a room, with one text message (A->B) and one
     * blurred media message (B->A) that A may mark viewed.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->userA = User::factory()->create();
        $this->userB = User::factory()->create();
        Friend::create([
            'user_id' => $this->userA->id,
            'friend_id' => $this->userB->id,
            'became_friends_at' => now(),
        ]);
        $room = Room::factory()->between($this->userA, $this->userB)->create();

        Chat::factory()->create([
            'sender_id' => $this->userA->id,
            'receiver_id' => $this->userB->id,
            'room_id' => $room->id,
            'text' => 'hi B',
            'message_type' => 'normal',
        ]);
        $this->media = Chat::factory()->blurredMedia()->create([
            'sender_id' => $this->userB->id,
            'receiver_id' => $this->userA->id,
            'room_id' => $room->id,
        ]);
    }

    /** The conversation endpoint (the 2026-05-23 endpoint) parses on v1.0.9. */
    #[Test]
    public function conversation_is_parseable_by_live_app(): void
    {
        $response = $this->actingAs($this->userA, 'api')
            ->getJson('/api/auth/chat/conversation/'.$this->userB->id);

        $response->assertOk();
        $this->assertSatisfiesLiveApp($response->json(), 'conversation');

        // Spell out the keystone guarantee: every message's is_viewed is an int.
        foreach ($response->json('data.chat') as $message) {
            $this->assertIsInt(
                $message['is_viewed'],
                'Private is_viewed must be an integer for the live v1.0.9 app.'
            );
        }
    }

    /** The mark-viewed gate response (patent flow) parses on v1.0.9. */
    #[Test]
    public function mark_viewed_is_parseable_by_live_app(): void
    {
        $response = $this->actingAs($this->userA, 'api')
            ->postJson('/api/auth/chat/mark-viewed/'.$this->media->id);

        $response->assertOk();
        $this->assertSatisfiesLiveApp($response->json(), 'mark-viewed');
        $this->assertIsInt($response->json('data.chat.is_viewed'));
    }

    /** The send response (incl. the 1:1 reaction upload leg) parses on v1.0.9. */
    #[Test]
    public function send_is_parseable_by_live_app(): void
    {
        $response = $this->actingAs($this->userA, 'api')
            ->postJson('/api/auth/chat/send/'.$this->userB->id, ['text' => 'sending now']);

        $response->assertOk();
        $this->assertSatisfiesLiveApp($response->json(), 'send');
        $this->assertIsInt($response->json('data.chat.is_viewed'));
    }

    /**
     * Intentional-break proof (A1 acceptance): demonstrate the guard has teeth.
     *
     * Feeds a conversation payload whose only defect is the exact 2026-05-23
     * regression — `is_viewed` as a JSON boolean instead of an integer — and
     * asserts the frozen v1.0.9 contract REJECTS it, naming the field. So if
     * the backend ever reverts is_viewed to bool, the endpoint tests above go
     * red here, not silently in production.
     */
    #[Test]
    public function boolean_is_viewed_is_rejected_by_the_live_app_contract(): void
    {
        $regressed = [
            'success' => true,
            'data' => [
                'chat' => [
                    [
                        'id' => 1,
                        'sender_id' => 2,
                        'receiver_id' => 1,
                        'room_id' => 3,
                        'text' => null,
                        'file' => 'https://example.invalid/x.jpg',
                        'status' => 'sent',
                        'is_blurred' => true,
                        'is_viewed' => true, // the regression: boolean, not integer
                        'message_type' => 'normal',
                        'is_my_text' => false,
                        'should_show_blur' => true,
                        'humanize_date' => 'now',
                        'short_text' => 'Media',
                        'type' => 'received',
                        'media_type' => 'image',
                    ],
                ],
            ],
        ];

        $errors = ContractMatcher::validate(
            $regressed,
            $this->loadLiveAppSchema('conversation')
        );

        $this->assertNotEmpty(
            $errors,
            'A boolean is_viewed must be rejected — otherwise the guard is toothless.'
        );
        $this->assertStringContainsString('is_viewed', implode("\n", $errors));
    }
}
