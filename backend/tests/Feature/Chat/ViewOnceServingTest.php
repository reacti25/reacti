<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * View-once private storage + authed streaming (P2b).
 *
 * Pins that one-time media is stored on the PRIVATE local disk (never the
 * public uploads dir), that the message serializes an authed endpoint URL
 * instead of a public asset URL, and that the endpoint streams only to a
 * participant. Consumption/destruction is a later phase; this locks the
 * serving boundary.
 */
class ViewOnceServingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        Storage::fake('local');
    }

    /** One-time media lands on the private disk, not the public uploads dir. */
    #[Test]
    public function one_time_media_is_stored_privately(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();

        $this->actingAs($sender, 'api')->post(
            "/api/auth/chat/send/{$receiver->id}",
            ['file' => UploadedFile::fake()->image('secret.jpg'), 'one_time' => 1],
            ['Accept' => 'application/json'],
        )->assertOk();

        $stored = Chat::first()->getRawOriginal('file');
        $this->assertStringStartsWith('viewonce/chat/', $stored);
        Storage::disk('local')->assertExists($stored);
    }

    /** The message serializes the authed endpoint URL, not a public asset URL. */
    #[Test]
    public function one_time_message_serializes_the_authed_endpoint_url(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();

        $resp = $this->actingAs($sender, 'api')->post(
            "/api/auth/chat/send/{$receiver->id}",
            ['file' => UploadedFile::fake()->image('secret.jpg'), 'one_time' => 1],
            ['Accept' => 'application/json'],
        );

        $url = $resp->json('data.chat.file');
        $this->assertStringContainsString('one-time-media', $url);
        $this->assertStringNotContainsString('uploads/', $url);
    }

    /** A participant can stream the one-time media; the endpoint returns 200. */
    #[Test]
    public function a_participant_can_stream_one_time_media(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();
        $chat = Chat::factory()->create([
            'sender_id' => $sender->id,
            'receiver_id' => $receiver->id,
            'one_time' => true,
            'consume_deadline' => now()->addMinutes(5),
            'file' => 'viewonce/chat/secret.jpg',
        ]);
        Storage::disk('local')->put('viewonce/chat/secret.jpg', 'bytes');

        $this->actingAs($receiver, 'api')
            ->get("/api/auth/chat/one-time-media/{$chat->id}")
            ->assertOk();
    }

    /** A non-participant is refused with 404 — no leak of who/what exists. */
    #[Test]
    public function a_non_participant_cannot_stream_one_time_media(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();
        $eve = User::factory()->create();
        $chat = Chat::factory()->create([
            'sender_id' => $sender->id,
            'receiver_id' => $receiver->id,
            'one_time' => true,
            'consume_deadline' => now()->addMinutes(5),
            'file' => 'viewonce/chat/secret.jpg',
        ]);
        Storage::disk('local')->put('viewonce/chat/secret.jpg', 'bytes');

        $this->actingAs($eve, 'api')
            ->get("/api/auth/chat/one-time-media/{$chat->id}")
            ->assertStatus(404);
    }

    /** Group one-time media is stored privately and streams to a member. */
    #[Test]
    public function group_one_time_media_is_private_and_member_gated(): void
    {
        $admin = User::factory()->create();
        $member = User::factory()->create();
        $outsider = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create(['group_id' => $group->id, 'user_id' => $admin->id]);
        GroupMember::factory()->create(['group_id' => $group->id, 'user_id' => $member->id]);

        $this->actingAs($admin, 'api')->post(
            "/api/auth/group/{$group->id}/send",
            ['file' => UploadedFile::fake()->image('secret.jpg'), 'one_time' => 1],
            ['Accept' => 'application/json'],
        )->assertOk();

        $message = GroupMessage::first();
        $this->assertStringStartsWith('viewonce/group_message/', $message->getRawOriginal('file'));
        Storage::disk('local')->assertExists($message->getRawOriginal('file'));

        $this->actingAs($member, 'api')
            ->get("/api/auth/group/one-time-media/{$message->id}")
            ->assertOk();

        $this->actingAs($outsider, 'api')
            ->get("/api/auth/group/one-time-media/{$message->id}")
            ->assertStatus(404);
    }
}
