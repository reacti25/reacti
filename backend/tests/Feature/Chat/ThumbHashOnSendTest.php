<?php

namespace Tests\Feature\Chat;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Sending an image computes and returns a ThumbHash placeholder; sending text
 * (or no image) returns null. Guards the end-to-end wiring: send →
 * ThumbHashService → stored column → API resource.
 */
class ThumbHashOnSendTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function sending_an_image_returns_a_thumb_hash(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->post(
            "/api/auth/chat/send/{$bob->id}",
            [
                'text' => '',
                'file' => UploadedFile::fake()->image('photo.jpg', 800, 600),
                'message_type' => 'normal',
            ],
        );

        $resp->assertOk();
        $hash = $resp->json('data.chat.thumb_hash');
        $this->assertIsString($hash);
        $this->assertNotEmpty($hash);
    }

    #[Test]
    public function sending_text_has_a_null_thumb_hash(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->post(
            "/api/auth/chat/send/{$bob->id}",
            ['text' => 'just text'],
        );

        $resp->assertOk();
        $this->assertNull($resp->json('data.chat.thumb_hash'));
    }
}
