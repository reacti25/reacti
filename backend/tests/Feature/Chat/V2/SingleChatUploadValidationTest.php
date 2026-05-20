<?php

namespace Tests\Feature\Chat\V2;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Upload validation on the v2 chat send endpoint.
 *
 * Before this change the rule was only `nullable|file|max:102400`,
 * accepting any mime type — a `.php` / `.svg` could land in the file
 * store. The rule now requires `mimes:jpg,jpeg,png,gif,mp4,mov,webm`.
 */
class SingleChatUploadValidationTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function send_rejects_a_php_upload(): void
    {
        Storage::fake('s3');

        $sender   = User::factory()->create();
        $receiver = User::factory()->create();

        $evil = UploadedFile::fake()->create(
            'evil.php',
            100,
            'application/x-php'
        );

        $resp = $this->actingAs($sender, 'api')->post(
            "/api/v2/auth/chat/send/{$receiver->id}",
            [
                'text'         => 'hi',
                'message_type' => 'normal',
                'file'         => $evil,
            ],
            ['Accept' => 'application/json']
        );

        $resp->assertStatus(422);
    }

    #[Test]
    public function send_rejects_an_svg_upload(): void
    {
        // SVGs are XML and can carry JS — even when the avatar rule
        // says `image`, svg sneaks past it; the explicit mime list
        // closes that gap.
        Storage::fake('s3');

        $sender   = User::factory()->create();
        $receiver = User::factory()->create();

        $svg = UploadedFile::fake()->create(
            'logo.svg',
            10,
            'image/svg+xml'
        );

        $resp = $this->actingAs($sender, 'api')->post(
            "/api/v2/auth/chat/send/{$receiver->id}",
            [
                'text'         => '',
                'message_type' => 'normal',
                'file'         => $svg,
            ],
            ['Accept' => 'application/json']
        );

        $resp->assertStatus(422);
    }
}
