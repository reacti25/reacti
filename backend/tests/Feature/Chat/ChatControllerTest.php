<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
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

    /**
     * Boot the framework, then swap the `public` disk for an in-memory fake
     * so uploaded-media assertions stay hermetic and start from an empty disk.
     */
    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    // -------- send (auth + validation, happy path is in ReactionFlowTest) --------

    /** No auth → 401. Anonymous client cannot send chat messages. */
    #[Test]
    public function send_requires_auth(): void
    {
        $other = User::factory()->create();
        $this->postJson("/api/auth/chat/send/{$other->id}", ['text' => 'hi'])
            ->assertStatus(401);
    }

    /**
     * Sender = receiver → success:false. The controller returns 200
     * but with success:false (not a 4xx) — that's the convention for
     * this controller. Pinning this so a future change to "return 400"
     * is caught.
     */
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

    /**
     * `message_type` is `nullable|in:normal,reaction` per the validator.
     * Anything else → 422. Pins the enum boundary — adding new types
     * (e.g. "audio") needs the validator updated AND this test to allow
     * the new value.
     */
    #[Test]
    public function send_rejects_message_type_outside_enum(): void
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();

        $resp = $this->actingAs($sender, 'api')->post(
            "/api/auth/chat/send/{$receiver->id}",
            ['text' => 'hi', 'message_type' => 'bogus'],
            ['Accept' => 'application/json'],
        );
        $resp->assertStatus(422);
    }

    // -------- mark-viewed --------

    /** No auth → 401. */
    #[Test]
    public function mark_viewed_requires_auth(): void
    {
        $this->postJson('/api/auth/chat/mark-viewed/1')->assertStatus(401);
    }

    /**
     * Mark-viewed is scoped to the *receiver* of the message — a third
     * party tries to mark Bob's message and gets 404 (the lookup is
     * `where receiver_id = current user`). Critical guard: without
     * it, an attacker who guesses a message id could forge "viewed"
     * indicators.
     */
    #[Test]
    public function mark_viewed_returns_404_when_message_does_not_target_user(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();
        $eve = User::factory()->create();
        $chat = Chat::factory()->create([
            'sender_id' => $alice->id,
            'receiver_id' => $bob->id,
        ]);

        $resp = $this->actingAs($eve, 'api')->postJson("/api/auth/chat/mark-viewed/{$chat->id}");
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 404);
    }

    // -------- list --------

    /**
     * Smoke test for the combined chat list endpoint. The auth user
     * with no conversations should still get a 200 back (empty list,
     * not a 404 or 500). The full union-of-1:1-and-groups logic is
     * implementation detail; here we just check the endpoint works.
     */
    #[Test]
    public function list_combined_returns_ok_for_authed_user(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user, 'api')->getJson('/api/auth/chat/list')->assertOk();
    }

    /** No auth → 401. */
    #[Test]
    public function list_combined_requires_auth(): void
    {
        $this->getJson('/api/auth/chat/list')->assertStatus(401);
    }

    // -------- conversation --------

    /** No auth → 401. */
    #[Test]
    public function conversation_requires_auth(): void
    {
        $other = User::factory()->create();
        $this->getJson("/api/auth/chat/conversation/{$other->id}")->assertStatus(401);
    }

    /**
     * Seed two messages — A→B and B→A — and fetch the conversation
     * from Alice's side. Both must appear in `data.chat`. A regression
     * that only returns "sent by me" or "received by me" would
     * collapse the conversation to one-sided.
     */
    #[Test]
    public function conversation_returns_messages_between_two_users(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();

        $aToB = Chat::factory()->create([
            'sender_id' => $alice->id,
            'receiver_id' => $bob->id,
            'text' => 'hi bob',
        ]);
        $bToA = Chat::factory()->create([
            'sender_id' => $bob->id,
            'receiver_id' => $alice->id,
            'text' => 'hi alice',
        ]);

        $resp = $this->actingAs($alice, 'api')->getJson("/api/auth/chat/conversation/{$bob->id}");
        $resp->assertOk();

        $ids = collect($resp->json('data.chat'))->pluck('id')->all();
        $this->assertContains($aToB->id, $ids);
        $this->assertContains($bToA->id, $ids);
    }

    // -------- room --------

    /**
     * Calling /room creates the `rooms` row on-demand if absent.
     * The convention is `user_one_id = min, user_two_id = max` so
     * the room is canonical regardless of who called from. Pinning
     * the min/max sort here protects the entire chat lookup pipeline
     * which assumes the canonical ordering.
     */
    #[Test]
    public function room_returns_or_creates_room_between_two_users(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->getJson("/api/auth/chat/room/{$bob->id}");
        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertDatabaseHas('rooms', [
            'user_one_id' => min($alice->id, $bob->id),
            'user_two_id' => max($alice->id, $bob->id),
        ]);
    }

    /** /room/{me} → success:false. No solo chat rooms. */
    #[Test]
    public function room_rejects_self(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->getJson("/api/auth/chat/room/{$user->id}");
        $resp->assertJsonPath('success', false);
    }

    /** No auth → 401. */
    #[Test]
    public function room_requires_auth(): void
    {
        $other = User::factory()->create();
        $this->getJson("/api/auth/chat/room/{$other->id}")->assertStatus(401);
    }

    // -------- search --------

    /** No auth → 401. */
    #[Test]
    public function search_requires_auth(): void
    {
        $this->getJson('/api/auth/chat/search')->assertStatus(401);
    }

    /**
     * /search returns 200 with a (possibly empty) result set. We don't
     * pin the exact match logic here — that's owned by `User` LIKE
     * queries in the controller — just that the endpoint works with
     * a keyword param.
     */
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

    /**
     * /seen/all/{sender} flips every message from `sender` to `me`
     * to status='read'. Used when the user opens a conversation —
     * one round trip clears the entire unread badge for that user.
     */
    #[Test]
    public function seen_all_marks_messages_from_sender_as_read(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();
        $chat = Chat::factory()->create([
            'sender_id' => $bob->id,
            'receiver_id' => $alice->id,
            'status' => 'sent',
        ]);

        $resp = $this->actingAs($alice, 'api')->getJson("/api/auth/chat/seen/all/{$bob->id}");
        $resp->assertOk();
        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'status' => 'read']);
    }

    /** /seen/all/{me} → success:false. */
    #[Test]
    public function seen_all_rejects_self(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->getJson("/api/auth/chat/seen/all/{$user->id}");
        $resp->assertJsonPath('success', false);
    }

    /** No auth → 401. */
    #[Test]
    public function seen_all_requires_auth(): void
    {
        $other = User::factory()->create();
        $this->getJson("/api/auth/chat/seen/all/{$other->id}")->assertStatus(401);
    }

    /**
     * /seen/single/{chat} flips a single chat row to status='read'.
     * Used when only one message is opened (e.g. tapped from a
     * notification deep-link).
     */
    #[Test]
    public function seen_single_marks_a_specific_chat_as_read(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();
        $chat = Chat::factory()->create([
            'sender_id' => $bob->id,
            'receiver_id' => $alice->id,
            'status' => 'sent',
        ]);

        $resp = $this->actingAs($alice, 'api')->getJson("/api/auth/chat/seen/single/{$chat->id}");
        $resp->assertOk();
        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'status' => 'read']);
    }

    /** No auth → 401. */
    #[Test]
    public function seen_single_requires_auth(): void
    {
        $this->getJson('/api/auth/chat/seen/single/1')->assertStatus(401);
    }

    // -------- delete chat --------

    /**
     * Deletes the entire conversation between two users. Room is
     * hard-deleted; chat rows can be either soft-deleted (Eloquent
     * SoftDeletes) or FK-cascaded depending on SQLite settings — we
     * assert "row is no longer live" rather than pinning either path.
     */
    #[Test]
    public function delete_chat_tears_down_the_conversation_and_the_room(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();

        // Seed the room between alice and bob explicitly so the controller's
        // user-pair lookup finds it (the ChatFactory's auto-created room is
        // between throwaway users, not alice/bob).
        $room = Room::factory()->between($alice, $bob)->create();
        $chat = Chat::factory()->create([
            'sender_id' => $alice->id,
            'receiver_id' => $bob->id,
            'room_id' => $room->id,
        ]);

        $resp = $this->actingAs($alice, 'api')->deleteJson("/api/auth/chat/delete/{$bob->id}");
        $resp->assertOk();
        $resp->assertJsonPath('success', true);

        // Room is hard-deleted; chat is either soft-deleted or FK-cascaded.
        $this->assertDatabaseMissing('rooms', ['id' => $room->id]);
        $this->assertDatabaseMissing('chats', [
            'id' => $chat->id,
            'deleted_at' => null,
        ]);
    }

    /**
     * Deleting a conversation that doesn't exist → code:404 in body.
     * No throw, no partial state mutation.
     */
    #[Test]
    public function delete_chat_returns_404_when_no_conversation_exists(): void
    {
        $alice = User::factory()->create();
        $bob = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->deleteJson("/api/auth/chat/delete/{$bob->id}");
        $resp->assertJsonPath('code', 404);
    }

    /** No auth → 401. */
    #[Test]
    public function delete_chat_requires_auth(): void
    {
        $other = User::factory()->create();
        $this->deleteJson("/api/auth/chat/delete/{$other->id}")->assertStatus(401);
    }

    // -------- delete single message --------

    /**
     * The validator on /delete/chat/messages requires
     * `exists:chats,id`. Bogus id → 422.
     */
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

    /** No auth → 401. */
    #[Test]
    public function delete_message_requires_auth(): void
    {
        $this->deleteJson('/api/auth/chat/delete/chat/messages', ['message_id' => 1])
            ->assertStatus(401);
    }
}
