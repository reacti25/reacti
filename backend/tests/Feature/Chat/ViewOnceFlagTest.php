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
 * View-once (`one_time`) flag plumbing — P1 of the view-once feature.
 *
 * Pins that the flag flows send → persist → serialize for both 1:1 and group,
 * that it is honoured only for a normal media send, and that ordinary media is
 * unaffected (default false). Nothing here exercises destruction/full-screen —
 * that lands in later phases; this locks the dark foundation.
 */
class ViewOnceFlagTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    /** A one-time media send persists one_time=true and serializes is_one_time=true. */
    #[Test]
    public function one_time_media_send_persists_and_serializes_the_flag(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();

        $resp = $this->actingAs($sender, 'api')->post(
            "/api/auth/chat/send/{$receiver->id}",
            ['file' => UploadedFile::fake()->image('photo.jpg'), 'one_time' => 1],
            ['Accept' => 'application/json'],
        );

        $resp->assertOk();
        $resp->assertJsonPath('data.chat.is_one_time', true);
        $this->assertTrue((bool) Chat::first()->one_time);
    }

    /** Without the toggle, an ordinary media send is not one-time. */
    #[Test]
    public function media_send_without_the_toggle_is_not_one_time(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();

        $resp = $this->actingAs($sender, 'api')->post(
            "/api/auth/chat/send/{$receiver->id}",
            ['file' => UploadedFile::fake()->image('photo.jpg')],
            ['Accept' => 'application/json'],
        );

        $resp->assertOk();
        $resp->assertJsonPath('data.chat.is_one_time', false);
        $this->assertFalse((bool) Chat::first()->one_time);
    }

    /** one_time is meaningless without media — a text send stays not-one-time. */
    #[Test]
    public function one_time_is_ignored_for_a_text_only_send(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();

        $resp = $this->actingAs($sender, 'api')->post(
            "/api/auth/chat/send/{$receiver->id}",
            ['text' => 'hi', 'one_time' => 1],
            ['Accept' => 'application/json'],
        );

        $resp->assertOk();
        $resp->assertJsonPath('data.chat.is_one_time', false);
        $this->assertFalse((bool) Chat::first()->one_time);
    }

    /** A non-boolean one_time value is rejected by the validator. */
    #[Test]
    public function one_time_rejects_a_non_boolean_value(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();

        $this->actingAs($sender, 'api')->post(
            "/api/auth/chat/send/{$receiver->id}",
            ['text' => 'hi', 'one_time' => 'maybe'],
            ['Accept' => 'application/json'],
        )->assertStatus(422);
    }

    /** The group send path plumbs one_time through the same way. */
    #[Test]
    public function group_one_time_media_send_persists_and_serializes_the_flag(): void
    {
        $admin = User::factory()->create();
        $member = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create(['group_id' => $group->id, 'user_id' => $admin->id]);
        GroupMember::factory()->create(['group_id' => $group->id, 'user_id' => $member->id]);

        $resp = $this->actingAs($admin, 'api')->post(
            "/api/auth/group/{$group->id}/send",
            ['file' => UploadedFile::fake()->image('photo.jpg'), 'one_time' => 1],
            ['Accept' => 'application/json'],
        );

        $resp->assertOk();
        $resp->assertJsonPath('data.message.is_one_time', true);
        $this->assertTrue((bool) GroupMessage::first()->one_time);
    }
}
