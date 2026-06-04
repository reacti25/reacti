<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Regression lock for the 1:1 conversation-history media URL.
 *
 * The conversation endpoint (GET /auth/chat/conversation/{id}) must serialize
 * each message's `file` as an ABSOLUTE URL. It previously emitted the raw
 * relative path stored in the column (e.g. `uploads/chat/x.jpg`), which the
 * Flutter client feeds straight into its image loader — a relative path cannot
 * resolve, so sent images saved correctly but rendered blank once the
 * conversation history was re-fetched. {@see ChatMessageResource::toArray()},
 * which now wraps `file` in asset() like every other serializer.
 */
class ConversationMediaUrlTest extends TestCase
{
    use RefreshDatabase;

    /**
     * A media message returned by the conversation endpoint carries an
     * absolute `file` URL (scheme + host), not a bare relative path.
     */
    #[Test]
    public function conversation_media_file_is_an_absolute_url(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();

        $relativePath = 'uploads/chat/example.jpg';
        $message = Chat::factory()->create([
            'sender_id' => $alice->id,
            'receiver_id' => $bob->id,
            'file' => $relativePath,
        ]);

        $resp = $this->actingAs($alice, 'api')
            ->getJson("/api/auth/chat/conversation/{$bob->id}");
        $resp->assertOk();

        $serialized = collect($resp->json('data.chat'))
            ->firstWhere('id', $message->id);

        $this->assertNotNull($serialized, 'Media message was missing from the conversation.');
        $this->assertStringStartsWith('http', $serialized['file'], 'file must be an absolute URL.');
        $this->assertStringContainsString($relativePath, $serialized['file'], 'URL must point at the stored path.');
        $this->assertSame(asset($relativePath), $serialized['file']);
    }
}
