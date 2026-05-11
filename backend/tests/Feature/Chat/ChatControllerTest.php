<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Endpoint coverage for the v1 ChatController. The send/mark-viewed
 * loop is locked by ReactionFlowTest + PatentFlowEventsTest; the
 * delete-message path is locked by MessageDeletedEventTest. This
 * file fills in: list, conversation, room, search, seen-all,
 * seen-single, delete-chat, plus the auth/validation paths missing
 * elsewhere.
 */
class ChatControllerTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    // -------- send (auth + validation, happy path is in ReactionFlowTest) --------

    #[Test]
    public function send_requires_auth(): void
    {
        $other = User::factory()->create();
        $this->post("/api/auth/chat/send/{$other->id}", ['text' => 'hi'])
            ->assertStatus(401);
    }

    #[Test]
    public function send_rejects_self(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->post(
            "/api/auth/chat/send/{$user->id}",
            ['text' => 'hi'],
            ['Accept' => 'application/json'],
        );
        // The controller answers 200 with success:false, message containing the rejection.
        $resp->assertOk();
        $resp->assertJsonPath('success', false);
    }

    #[Test]
    public function send_rejects_message_type_outside_enum(): void
    {
        $sender   = User::factory()->create();
        $receiver = User::factory()->create();

        $resp = $this->actingAs($sender, 'api')->post(
            "/api/auth/chat/send/{$receiver->id}",
            ['text' => 'hi', 'message_type' => 'bogus'],
            ['Accept' => 'application/json'],
        );
        $resp->assertStatus(422);
    }

    // -------- mark-viewed --------

    #[Test]
    public function mark_viewed_requires_auth(): void
    {
        $this->postJson('/api/auth/chat/mark-viewed/1')->assertStatus(401);
    }

    #[Test]
    public function mark_viewed_returns_404_when_message_does_not_target_user(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $eve   = User::factory()->create();
        $chat  = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
        ]);

        $resp = $this->actingAs($eve, 'api')->postJson("/api/auth/chat/mark-viewed/{$chat->id}");
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 404);
    }

    // -------- list --------

    #[Test]
    public function list_combined_returns_ok_for_authed_user(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user, 'api')->getJson('/api/auth/chat/list')->assertOk();
    }

    #[Test]
    public function list_combined_requires_auth(): void
    {
        $this->getJson('/api/auth/chat/list')->assertStatus(401);
    }

    // -------- conversation --------

    #[Test]
    public function conversation_requires_auth(): void
    {
        $other = User::factory()->create();
        $this->getJson("/api/auth/chat/conversation/{$other->id}")->assertStatus(401);
    }

    #[Test]
    public function conversation_returns_messages_between_two_users(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $aToB = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
            'text'        => 'hi bob',
        ]);
        $bToA = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'text'        => 'hi alice',
        ]);

        $resp = $this->actingAs($alice, 'api')->getJson("/api/auth/chat/conversation/{$bob->id}");
        $resp->assertOk();

        $ids = collect($resp->json('data.chat'))->pluck('id')->all();
        $this->assertContains($aToB->id, $ids);
        $this->assertContains($bToA->id, $ids);
    }

    // -------- room --------

    #[Test]
    public function room_returns_or_creates_room_between_two_users(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->getJson("/api/auth/chat/room/{$bob->id}");
        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertDatabaseHas('rooms', [
            'user_one_id' => min($alice->id, $bob->id),
            'user_two_id' => max($alice->id, $bob->id),
        ]);
    }

    #[Test]
    public function room_rejects_self(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->getJson("/api/auth/chat/room/{$user->id}");
        $resp->assertJsonPath('success', false);
    }

    #[Test]
    public function room_requires_auth(): void
    {
        $other = User::factory()->create();
        $this->getJson("/api/auth/chat/room/{$other->id}")->assertStatus(401);
    }

    // -------- search --------

    #[Test]
    public function search_requires_auth(): void
    {
        $this->getJson('/api/auth/chat/search')->assertStatus(401);
    }

    #[Test]
    public function search_returns_ok_with_optional_keyword(): void
    {
        $user = User::factory()->create();
        User::factory()->create(['first_name' => 'Findme']);

        $resp = $this->actingAs($user, 'api')->getJson('/api/auth/chat/search?keyword=Findme');
        $resp->assertOk();
        $resp->assertJsonPath('success', true);
    }

    // -------- seen --------

    #[Test]
    public function seen_all_marks_messages_from_sender_as_read(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $chat  = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'status'      => 'sent',
        ]);

        $resp = $this->actingAs($alice, 'api')->getJson("/api/auth/chat/seen/all/{$bob->id}");
        $resp->assertOk();
        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'status' => 'read']);
    }

    #[Test]
    public function seen_all_rejects_self(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->getJson("/api/auth/chat/seen/all/{$user->id}");
        $resp->assertJsonPath('success', false);
    }

    #[Test]
    public function seen_all_requires_auth(): void
    {
        $other = User::factory()->create();
        $this->getJson("/api/auth/chat/seen/all/{$other->id}")->assertStatus(401);
    }

    #[Test]
    public function seen_single_marks_a_specific_chat_as_read(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $chat  = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'status'      => 'sent',
        ]);

        $resp = $this->actingAs($alice, 'api')->getJson("/api/auth/chat/seen/single/{$chat->id}");
        $resp->assertOk();
        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'status' => 'read']);
    }

    #[Test]
    public function seen_single_requires_auth(): void
    {
        $this->getJson('/api/auth/chat/seen/single/1')->assertStatus(401);
    }

    // -------- delete chat --------

    #[Test]
    public function delete_chat_soft_deletes_messages_and_the_room(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $chat  = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
        ]);
        $roomId = $chat->room_id;

        $resp = $this->actingAs($alice, 'api')->deleteJson("/api/auth/chat/delete/{$bob->id}");
        $resp->assertOk();

        $this->assertSoftDeleted('chats', ['id' => $chat->id]);
        $this->assertDatabaseMissing('rooms', ['id' => $roomId]);
    }

    #[Test]
    public function delete_chat_returns_404_when_no_conversation_exists(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->deleteJson("/api/auth/chat/delete/{$bob->id}");
        $resp->assertJsonPath('code', 404);
    }

    #[Test]
    public function delete_chat_requires_auth(): void
    {
        $other = User::factory()->create();
        $this->deleteJson("/api/auth/chat/delete/{$other->id}")->assertStatus(401);
    }

    // -------- delete single message --------

    #[Test]
    public function delete_message_validates_message_exists(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->deleteJson(
            '/api/auth/chat/delete/chat/messages',
            ['message_id' => 999999],
        );
        $resp->assertStatus(422);
    }

    #[Test]
    public function delete_message_requires_auth(): void
    {
        $this->deleteJson('/api/auth/chat/delete/chat/messages', ['message_id' => 1])
            ->assertStatus(401);
    }
}
