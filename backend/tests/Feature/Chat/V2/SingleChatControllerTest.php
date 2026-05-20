<?php

namespace Tests\Feature\Chat\V2;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Protective Feature-test suite for the V2 SingleChatController, which
 * serves the `v2/auth/chat/*` routes.
 *
 * This file pins the controller's CURRENT behaviour — exact status
 * codes, envelope shapes, validation rules, permission guards, DB
 * writes — ahead of a planned refactor, so the refactor can be
 * verified behaviour-preserving. It is intentionally written against
 * the un-refactored controller and every assertion reflects what the
 * code does TODAY, including quirks (e.g. forwardMessage's `404`
 * branch is unreachable because the validator already rejects a
 * missing `message_id` with `422`).
 *
 * Hermetic: RefreshDatabase, the `s3` and `public` disks are faked,
 * uploads use UploadedFile::fake(), and broadcasts are inert because
 * the test environment sets `BROADCAST_CONNECTION=null`. Push
 * notifications stay no-op because recipients are created without any
 * Firebase tokens (sendPushNotification() bails when the receiver has
 * no registered devices).
 */
class SingleChatControllerTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Boot the framework, then swap the `s3` and `public` disks for
     * in-memory fakes so media uploads/deletions stay hermetic. The V2
     * controller writes media to the `s3` disk (unlike V1's `public`).
     */
    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('s3');
        Storage::fake('public');
    }

    // =====================================================================
    // GET /list  →  listCombined
    // =====================================================================

    /** No auth → 401. The combined chat list is behind auth:api. */
    #[Test]
    public function list_combined_requires_auth(): void
    {
        $this->getJson('/api/v2/auth/chat/list')->assertStatus(401);
    }

    /**
     * An authed user with no conversations still gets 200 with the
     * success envelope — an empty list, never a 404 or 500.
     */
    #[Test]
    public function list_combined_returns_ok_for_authed_user_with_no_chats(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->getJson('/api/v2/auth/chat/list');

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
    }

    /**
     * The list surfaces a 1:1 conversation the auth user is part of.
     * Seeding one message from Bob to Alice means Alice's list is
     * non-empty when she fetches it.
     */
    #[Test]
    public function list_combined_includes_a_one_to_one_conversation(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $room = Room::factory()->between($alice, $bob)->create();
        Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'room_id'     => $room->id,
        ]);

        $resp = $this->actingAs($alice, 'api')->getJson('/api/v2/auth/chat/list');

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        // The CombinedChatCollection nests entries under `data.chats`
        // (alongside `data.pagination`), and each direct-chat entry is
        // keyed by the *other user's* id. Bob should appear there.
        $ids = collect($resp->json('data.chats'))->pluck('id')->all();
        $this->assertContains($bob->id, $ids);
    }

    /**
     * A keyword query is honoured and still returns the success
     * envelope (keyword search bypasses the per-user cache).
     */
    #[Test]
    public function list_combined_accepts_a_keyword_query(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')
            ->getJson('/api/v2/auth/chat/list?keyword=nobody');

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
    }

    // =====================================================================
    // POST /send/{receiver_id}  →  send
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function send_requires_auth(): void
    {
        $other = User::factory()->create();

        $this->postJson("/api/v2/auth/chat/send/{$other->id}", ['text' => 'hi'])
            ->assertStatus(401);
    }

    /**
     * Happy path: a text-only message is created, broadcast, and the
     * created chat is returned as a ChatResource at `data.chat`.
     */
    #[Test]
    public function send_creates_a_text_message_and_returns_it(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->postJson(
            "/api/v2/auth/chat/send/{$bob->id}",
            ['text' => 'hello bob']
        );

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonPath('code', 200);

        $messageId = $resp->json('data.chat.id');
        $this->assertNotNull($messageId);
        $this->assertDatabaseHas('chats', [
            'id'          => $messageId,
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
            'text'        => 'hello bob',
            'status'      => 'sent',
            'is_blurred'  => 0,
        ]);
    }

    /**
     * A `normal` media message is stored `is_blurred=true` for the
     * patent flow, and the file is uploaded to the (faked) s3 disk.
     */
    #[Test]
    public function send_stores_normal_media_message_as_blurred(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->post(
            "/api/v2/auth/chat/send/{$bob->id}",
            [
                'text'         => '',
                'message_type' => 'normal',
                'file'         => UploadedFile::fake()->image('photo.jpg', 640, 480),
            ],
            ['Accept' => 'application/json']
        );

        $resp->assertOk();
        $resp->assertJsonPath('success', true);

        $this->assertDatabaseHas('chats', [
            'id'           => $resp->json('data.chat.id'),
            'message_type' => 'normal',
            'is_blurred'   => 1,
            'is_viewed'    => 0,
            'file_type'    => 'image',
        ]);
    }

    /**
     * A `reaction` media message is NOT blurred — only `normal` media
     * is blurred. Pins the message_type → is_blurred branch.
     */
    #[Test]
    public function send_does_not_blur_reaction_media_messages(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($bob, 'api')->post(
            "/api/v2/auth/chat/send/{$alice->id}",
            [
                'text'         => '',
                'message_type' => 'reaction',
                'file'         => UploadedFile::fake()->create('reaction.mp4', 120, 'video/mp4'),
            ],
            ['Accept' => 'application/json']
        );

        $resp->assertOk();
        $this->assertDatabaseHas('chats', [
            'id'           => $resp->json('data.chat.id'),
            'message_type' => 'reaction',
            'is_blurred'   => 0,
        ]);
    }

    /**
     * Sending to a non-existent user → 400 with success:false. The
     * controller treats unknown receiver and self-target identically.
     */
    #[Test]
    public function send_returns_400_for_unknown_receiver(): void
    {
        $alice = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->postJson('/api/v2/auth/chat/send/999999', ['text' => 'hi']);

        $resp->assertStatus(400);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 400);
    }

    /**
     * Sending to yourself → 400 with success:false. Unlike the V1
     * controller (which answers 200/success:false), V2 returns a real
     * 400 status — pinning the V2-specific behaviour.
     */
    #[Test]
    public function send_rejects_self_with_400(): void
    {
        $alice = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->postJson("/api/v2/auth/chat/send/{$alice->id}", ['text' => 'hi']);

        $resp->assertStatus(400);
        $resp->assertJsonPath('success', false);
    }

    /**
     * If either user has blocked the other, the send is refused with
     * 403. Here the receiver has blocked the sender.
     */
    #[Test]
    public function send_returns_403_when_pair_is_blocked(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        // Bob blocks Alice.
        DB::table('user_blocks')->insert([
            'user_id'       => $bob->id,
            'block_user_id' => $alice->id,
            'created_at'    => now(),
            'updated_at'    => now(),
        ]);

        $resp = $this->actingAs($alice, 'api')
            ->postJson("/api/v2/auth/chat/send/{$bob->id}", ['text' => 'hi']);

        $resp->assertStatus(403);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 403);
    }

    /**
     * `message_type` is `nullable|in:normal,reaction,reply`; anything
     * else fails validation → 422.
     */
    #[Test]
    public function send_rejects_message_type_outside_enum(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->postJson(
            "/api/v2/auth/chat/send/{$bob->id}",
            ['text' => 'hi', 'message_type' => 'bogus']
        );

        $resp->assertStatus(422);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 422);
    }

    /**
     * `reply_to_id` must reference an existing chat row; a bogus id
     * fails the `exists:chats,id` rule → 422.
     */
    #[Test]
    public function send_rejects_unknown_reply_to_id(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->postJson(
            "/api/v2/auth/chat/send/{$bob->id}",
            ['text' => 'hi', 'reply_to_id' => 999999]
        );

        $resp->assertStatus(422);
    }

    /**
     * `text` is capped at 5000 characters; longer text → 422.
     */
    #[Test]
    public function send_rejects_text_over_the_max_length(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->postJson(
            "/api/v2/auth/chat/send/{$bob->id}",
            ['text' => str_repeat('a', 5001)]
        );

        $resp->assertStatus(422);
    }

    // =====================================================================
    // GET /conversation/{receiver_id}  →  conversation
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function conversation_requires_auth(): void
    {
        $other = User::factory()->create();

        $this->getJson("/api/v2/auth/chat/conversation/{$other->id}")
            ->assertStatus(401);
    }

    /**
     * The conversation returns both directions of messages between the
     * two users, plus the documented data envelope keys.
     */
    #[Test]
    public function conversation_returns_messages_between_two_users(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $room = Room::factory()->between($alice, $bob)->create();
        $aToB = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
            'room_id'     => $room->id,
        ]);
        $bToA = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'room_id'     => $room->id,
        ]);

        $resp = $this->actingAs($alice, 'api')
            ->getJson("/api/v2/auth/chat/conversation/{$bob->id}");

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonStructure([
            'data' => ['receiver', 'sender', 'room', 'chat', 'pagination', 'is_blocked', 'block_by_me'],
        ]);

        $ids = collect($resp->json('data.chat'))->pluck('id')->all();
        $this->assertContains($aToB->id, $ids);
        $this->assertContains($bToA->id, $ids);
    }

    /**
     * Opening a conversation bulk-marks the other user's unread
     * messages to status='read'.
     */
    #[Test]
    public function conversation_marks_incoming_messages_as_read(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $room = Room::factory()->between($alice, $bob)->create();
        $chat = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'room_id'     => $room->id,
            'status'      => 'sent',
        ]);

        $this->actingAs($alice, 'api')
            ->getJson("/api/v2/auth/chat/conversation/{$bob->id}")
            ->assertOk();

        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'status' => 'read']);
    }

    /**
     * An unviewed media message the auth user received is flagged
     * `should_show_blur=true` (drives the patent blur placeholder).
     */
    #[Test]
    public function conversation_flags_unviewed_received_media_as_blurred(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $room = Room::factory()->between($alice, $bob)->create();
        $media = Chat::factory()->blurredMedia()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'room_id'     => $room->id,
        ]);

        $resp = $this->actingAs($alice, 'api')
            ->getJson("/api/v2/auth/chat/conversation/{$bob->id}");

        $resp->assertOk();
        $entry = collect($resp->json('data.chat'))->firstWhere('id', $media->id);
        $this->assertNotNull($entry);
        $this->assertTrue($entry['should_show_blur']);
    }

    /** Conversation with an unknown user → 404. */
    #[Test]
    public function conversation_returns_404_for_unknown_receiver(): void
    {
        $alice = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->getJson('/api/v2/auth/chat/conversation/999999');

        $resp->assertStatus(404);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 404);
    }

    /** Conversation with yourself → 404 (self-target rejected). */
    #[Test]
    public function conversation_rejects_self_with_404(): void
    {
        $alice = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->getJson("/api/v2/auth/chat/conversation/{$alice->id}");

        $resp->assertStatus(404);
        $resp->assertJsonPath('success', false);
    }

    // =====================================================================
    // GET /room/{receiver_id}  →  room
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function room_requires_auth(): void
    {
        $other = User::factory()->create();

        $this->getJson("/api/v2/auth/chat/room/{$other->id}")
            ->assertStatus(401);
    }

    /**
     * Fetching a room lazily creates the `rooms` row using the
     * canonical min/max user-id ordering.
     */
    #[Test]
    public function room_returns_or_creates_room_between_two_users(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->getJson("/api/v2/auth/chat/room/{$bob->id}");

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertDatabaseHas('rooms', [
            'user_one_id' => min($alice->id, $bob->id),
            'user_two_id' => max($alice->id, $bob->id),
        ]);
    }

    /** /room with an unknown user → 400 with success:false. */
    #[Test]
    public function room_returns_400_for_unknown_user(): void
    {
        $alice = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->getJson('/api/v2/auth/chat/room/999999');

        $resp->assertStatus(400);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 400);
    }

    /** /room/{me} → 400 with success:false. No solo chat rooms. */
    #[Test]
    public function room_rejects_self_with_400(): void
    {
        $alice = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->getJson("/api/v2/auth/chat/room/{$alice->id}");

        $resp->assertStatus(400);
        $resp->assertJsonPath('success', false);
    }

    // =====================================================================
    // GET /search  →  search
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function search_requires_auth(): void
    {
        $this->getJson('/api/v2/auth/chat/search')->assertStatus(401);
    }

    /**
     * A keyword search returns matching users (excluding the auth
     * user) under `data.users`.
     */
    #[Test]
    public function search_returns_matching_users_for_a_keyword(): void
    {
        $user  = User::factory()->create();
        $match = User::factory()->create(['first_name' => 'Findme']);

        $resp = $this->actingAs($user, 'api')
            ->getJson('/api/v2/auth/chat/search?keyword=Findme');

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $ids = collect($resp->json('data.users'))->pluck('id')->all();
        $this->assertContains($match->id, $ids);
    }

    /** Search never returns the auth user, even if they match the keyword. */
    #[Test]
    public function search_excludes_the_authenticated_user(): void
    {
        $user = User::factory()->create(['first_name' => 'Uniquename']);

        $resp = $this->actingAs($user, 'api')
            ->getJson('/api/v2/auth/chat/search?keyword=Uniquename');

        $resp->assertOk();
        $ids = collect($resp->json('data.users'))->pluck('id')->all();
        $this->assertNotContains($user->id, $ids);
    }

    /** Search with no keyword → 400 with success:false. */
    #[Test]
    public function search_returns_400_when_keyword_missing(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')
            ->getJson('/api/v2/auth/chat/search');

        $resp->assertStatus(400);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 400);
    }

    // =====================================================================
    // GET /seen/all/{receiver_id}  →  seenAll
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function seen_all_requires_auth(): void
    {
        $other = User::factory()->create();

        $this->getJson("/api/v2/auth/chat/seen/all/{$other->id}")
            ->assertStatus(401);
    }

    /**
     * /seen/all/{sender} flips every message from that sender to the
     * auth user to status='read' and reports the updated count.
     */
    #[Test]
    public function seen_all_marks_messages_from_sender_as_read(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $room = Room::factory()->between($alice, $bob)->create();
        $chat = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'room_id'     => $room->id,
            'status'      => 'sent',
        ]);

        $resp = $this->actingAs($alice, 'api')
            ->getJson("/api/v2/auth/chat/seen/all/{$bob->id}");

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonPath('data.updated_count', 1);
        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'status' => 'read']);
    }

    /** /seen/all with an unknown user → 400 with success:false. */
    #[Test]
    public function seen_all_returns_400_for_unknown_user(): void
    {
        $alice = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->getJson('/api/v2/auth/chat/seen/all/999999');

        $resp->assertStatus(400);
        $resp->assertJsonPath('success', false);
    }

    /** /seen/all/{me} → 400 with success:false. */
    #[Test]
    public function seen_all_rejects_self_with_400(): void
    {
        $alice = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->getJson("/api/v2/auth/chat/seen/all/{$alice->id}");

        $resp->assertStatus(400);
        $resp->assertJsonPath('success', false);
    }

    // =====================================================================
    // GET /seen/single/{chat_id}  →  seenSingle
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function seen_single_requires_auth(): void
    {
        $this->getJson('/api/v2/auth/chat/seen/single/1')
            ->assertStatus(401);
    }

    /** /seen/single/{chat} flips a single received chat row to read. */
    #[Test]
    public function seen_single_marks_a_specific_chat_as_read(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'status'      => 'sent',
        ]);

        $resp = $this->actingAs($alice, 'api')
            ->getJson("/api/v2/auth/chat/seen/single/{$chat->id}");

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'status' => 'read']);
    }

    /**
     * A message that does not target the auth user yields 404 — the
     * lookup is scoped by `receiver_id = auth user`.
     */
    #[Test]
    public function seen_single_returns_404_when_message_does_not_target_user(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $eve   = User::factory()->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
            'status'      => 'sent',
        ]);

        $resp = $this->actingAs($eve, 'api')
            ->getJson("/api/v2/auth/chat/seen/single/{$chat->id}");

        $resp->assertStatus(404);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 404);
    }

    /**
     * An already-read message yields 404 — the update is scoped to
     * `status != read`, so a no-op affecting zero rows is treated as
     * "not found or already read".
     */
    #[Test]
    public function seen_single_returns_404_when_message_already_read(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'status'      => 'read',
        ]);

        $resp = $this->actingAs($alice, 'api')
            ->getJson("/api/v2/auth/chat/seen/single/{$chat->id}");

        $resp->assertStatus(404);
        $resp->assertJsonPath('success', false);
    }

    /** An unknown chat id → 404. */
    #[Test]
    public function seen_single_returns_404_for_unknown_chat(): void
    {
        $alice = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->getJson('/api/v2/auth/chat/seen/single/999999');

        $resp->assertStatus(404);
        $resp->assertJsonPath('success', false);
    }

    // =====================================================================
    // POST /mark-viewed/{message_id}  →  markAsViewed
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function mark_viewed_requires_auth(): void
    {
        $this->postJson('/api/v2/auth/chat/mark-viewed/1')
            ->assertStatus(401);
    }

    /**
     * The receiver marks a blurred media message as viewed — the row
     * flips to is_viewed=true / is_blurred=false (patent unblur).
     */
    #[Test]
    public function mark_viewed_unblurs_a_received_media_message(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $chat = Chat::factory()->blurredMedia()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
        ]);

        $resp = $this->actingAs($bob, 'api')
            ->postJson("/api/v2/auth/chat/mark-viewed/{$chat->id}");

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertDatabaseHas('chats', [
            'id'         => $chat->id,
            'is_viewed'  => 1,
            'is_blurred' => 0,
        ]);
    }

    /**
     * Mark-viewed is scoped to the receiver: a third party who guesses
     * a message id gets 404, never the ability to forge a "viewed".
     */
    #[Test]
    public function mark_viewed_returns_404_when_message_does_not_target_user(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $eve   = User::factory()->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
        ]);

        $resp = $this->actingAs($eve, 'api')
            ->postJson("/api/v2/auth/chat/mark-viewed/{$chat->id}");

        $resp->assertStatus(404);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 404);
    }

    /**
     * Even the message's own sender cannot mark it viewed — the scope
     * is `receiver_id = auth user`, so the sender gets 404.
     */
    #[Test]
    public function mark_viewed_returns_404_for_the_sender(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
        ]);

        $resp = $this->actingAs($alice, 'api')
            ->postJson("/api/v2/auth/chat/mark-viewed/{$chat->id}");

        $resp->assertStatus(404);
        $resp->assertJsonPath('success', false);
    }

    /** An unknown message id → 404. */
    #[Test]
    public function mark_viewed_returns_404_for_unknown_message(): void
    {
        $alice = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->postJson('/api/v2/auth/chat/mark-viewed/999999');

        $resp->assertStatus(404);
        $resp->assertJsonPath('success', false);
    }

    // =====================================================================
    // DELETE /delete/{receiver_id}  →  deleteChat
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function delete_chat_requires_auth(): void
    {
        $other = User::factory()->create();

        $this->deleteJson("/api/v2/auth/chat/delete/{$other->id}")
            ->assertStatus(401);
    }

    /**
     * Deleting a conversation removes the room and its messages outright.
     *
     * Although the `Chat` model uses SoftDeletes, the `chats.room_id`
     * foreign key is declared `onDelete('cascade')`, so once the room is
     * hard-deleted the database cascade hard-removes the chat rows too —
     * they do not survive as soft-deleted records.
     */
    #[Test]
    public function delete_chat_tears_down_the_conversation_and_the_room(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $room = Room::factory()->between($alice, $bob)->create();
        $chat = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
            'room_id'     => $room->id,
        ]);

        $resp = $this->actingAs($alice, 'api')
            ->deleteJson("/api/v2/auth/chat/delete/{$bob->id}");

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertDatabaseMissing('rooms', ['id' => $room->id]);
        // The room delete cascades to the chats rows (FK onDelete cascade).
        $this->assertDatabaseMissing('chats', ['id' => $chat->id]);
    }

    /**
     * Deleting a conversation that does not exist → 404 with
     * success:false; no partial mutation.
     */
    #[Test]
    public function delete_chat_returns_404_when_no_conversation_exists(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->deleteJson("/api/v2/auth/chat/delete/{$bob->id}");

        $resp->assertStatus(404);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 404);
    }

    /**
     * The room lookup is direction-agnostic: a room seeded with the
     * canonical min/max ordering is still found when the higher-id
     * user requests the delete.
     */
    #[Test]
    public function delete_chat_finds_the_room_regardless_of_caller(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $room = Room::factory()->between($alice, $bob)->create();

        // The higher-id user initiates the delete.
        $caller   = $alice->id > $bob->id ? $alice : $bob;
        $other    = $alice->id > $bob->id ? $bob : $alice;

        $resp = $this->actingAs($caller, 'api')
            ->deleteJson("/api/v2/auth/chat/delete/{$other->id}");

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertDatabaseMissing('rooms', ['id' => $room->id]);
    }

    // =====================================================================
    // DELETE /delete/chat/messages  →  deleteMessage
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function delete_message_requires_auth(): void
    {
        $this->deleteJson('/api/v2/auth/chat/delete/chat/messages', ['message_id' => 1])
            ->assertStatus(401);
    }

    /**
     * `message_id` is `required|exists:chats,id`; a missing id → 422.
     */
    #[Test]
    public function delete_message_returns_422_when_message_id_missing(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')
            ->deleteJson('/api/v2/auth/chat/delete/chat/messages', []);

        $resp->assertStatus(422);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 422);
    }

    /** A `message_id` that does not exist fails `exists:chats,id` → 422. */
    #[Test]
    public function delete_message_returns_422_for_unknown_message_id(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')
            ->deleteJson('/api/v2/auth/chat/delete/chat/messages', ['message_id' => 999999]);

        $resp->assertStatus(422);
    }

    /** The sender of a message may delete it; the row is soft-deleted. */
    #[Test]
    public function delete_message_lets_the_sender_delete_their_message(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
        ]);

        $resp = $this->actingAs($alice, 'api')
            ->deleteJson('/api/v2/auth/chat/delete/chat/messages', ['message_id' => $chat->id]);

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertSoftDeleted('chats', ['id' => $chat->id]);
    }

    /** The receiver of a message may also delete it. */
    #[Test]
    public function delete_message_lets_the_receiver_delete_the_message(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
        ]);

        $resp = $this->actingAs($bob, 'api')
            ->deleteJson('/api/v2/auth/chat/delete/chat/messages', ['message_id' => $chat->id]);

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertSoftDeleted('chats', ['id' => $chat->id]);
    }

    /**
     * A third party who is neither sender nor receiver gets 404 —
     * the message lookup is scoped to the caller's own messages.
     */
    #[Test]
    public function delete_message_returns_404_for_a_non_participant(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $eve   = User::factory()->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
        ]);

        $resp = $this->actingAs($eve, 'api')
            ->deleteJson('/api/v2/auth/chat/delete/chat/messages', ['message_id' => $chat->id]);

        $resp->assertStatus(404);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 404);
        // The message survives an unauthorised delete attempt.
        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'deleted_at' => null]);
    }

    // =====================================================================
    // POST /forward  →  forwardMessage
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function forward_requires_auth(): void
    {
        $this->postJson('/api/v2/auth/chat/forward', ['message_id' => 1, 'receiver_ids' => [2]])
            ->assertStatus(401);
    }

    /**
     * Forwarding copies the original message into a fresh chat row for
     * each recipient, stamps `forwarded_from`, and reports the count.
     */
    #[Test]
    public function forward_copies_a_message_to_each_recipient(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $carol = User::factory()->create();

        $original = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'text'        => 'forward me',
        ]);

        $resp = $this->actingAs($alice, 'api')->postJson('/api/v2/auth/chat/forward', [
            'message_id'   => $original->id,
            'receiver_ids' => [$bob->id, $carol->id],
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonPath('data.forwarded_count', 2);

        $this->assertDatabaseHas('chats', [
            'sender_id'      => $alice->id,
            'receiver_id'    => $carol->id,
            'text'           => 'forward me',
            'message_type'   => 'normal',
            'forwarded_from' => $bob->id,
        ]);
    }

    /**
     * Forwarding to a list that includes the auth user skips the self
     * entry — only the other recipients receive a copy.
     */
    #[Test]
    public function forward_skips_the_auth_user_in_the_recipient_list(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $original = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
        ]);

        $resp = $this->actingAs($alice, 'api')->postJson('/api/v2/auth/chat/forward', [
            'message_id'   => $original->id,
            'receiver_ids' => [$alice->id, $bob->id],
        ]);

        $resp->assertOk();
        // Alice is skipped; only Bob receives the forward.
        $resp->assertJsonPath('data.forwarded_count', 1);
        $this->assertDatabaseMissing('chats', [
            'sender_id'      => $alice->id,
            'receiver_id'    => $alice->id,
            'forwarded_from' => $bob->id,
        ]);
    }

    /**
     * A missing `message_id` fails the `required|exists:chats,id` rule
     * → 422.
     */
    #[Test]
    public function forward_returns_422_when_message_id_missing(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->postJson('/api/v2/auth/chat/forward', [
            'receiver_ids' => [$bob->id],
        ]);

        $resp->assertStatus(422);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 422);
    }

    /**
     * An unknown `message_id` fails `exists:chats,id` → 422. NOTE: the
     * controller's own `if (!$originalMessage) { ... 404 }` branch is
     * therefore unreachable — the validator rejects a missing message
     * with 422 before that check runs. This test pins the actual 422
     * behaviour; the 404 branch is effectively dead code.
     */
    #[Test]
    public function forward_returns_422_for_unknown_message_id(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->postJson('/api/v2/auth/chat/forward', [
            'message_id'   => 999999,
            'receiver_ids' => [$bob->id],
        ]);

        $resp->assertStatus(422);
    }

    /** `receiver_ids` is `required|array`; a missing array → 422. */
    #[Test]
    public function forward_returns_422_when_receiver_ids_missing(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $original = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
        ]);

        $resp = $this->actingAs($alice, 'api')->postJson('/api/v2/auth/chat/forward', [
            'message_id' => $original->id,
        ]);

        $resp->assertStatus(422);
    }

    /**
     * Each entry of `receiver_ids` must be a real user (`exists:users,id`);
     * an unknown id → 422.
     */
    #[Test]
    public function forward_returns_422_for_an_unknown_recipient(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $original = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
        ]);

        $resp = $this->actingAs($alice, 'api')->postJson('/api/v2/auth/chat/forward', [
            'message_id'   => $original->id,
            'receiver_ids' => [999999],
        ]);

        $resp->assertStatus(422);
    }

    // =====================================================================
    // POST /typing/{receiver_id}  →  typingStatus
    // =====================================================================

    /** No auth → 401. */
    #[Test]
    public function typing_status_requires_auth(): void
    {
        $other = User::factory()->create();

        $this->postJson("/api/v2/auth/chat/typing/{$other->id}", ['is_typing' => true])
            ->assertStatus(401);
    }

    /**
     * Happy path: a valid is_typing flag dispatches the broadcast and
     * returns 200. The original code referenced
     * `\App\Events\UserTypingEvent` (non-existent — every call 500'd);
     * fixed to the real `\App\Events\Chat\V2\UserTypingEvent`.
     */
    #[Test]
    public function typing_status_broadcasts_and_returns_200(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->postJson(
            "/api/v2/auth/chat/typing/{$bob->id}",
            ['is_typing' => true]
        );

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
    }

    /** `is_typing` is `required`; omitting it → 422. */
    #[Test]
    public function typing_status_returns_422_when_is_typing_missing(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')
            ->postJson("/api/v2/auth/chat/typing/{$bob->id}", []);

        $resp->assertStatus(422);
        $resp->assertJsonPath('success', false);
        $resp->assertJsonPath('code', 422);
    }

    /** `is_typing` must be boolean; a non-boolean value → 422. */
    #[Test]
    public function typing_status_returns_422_for_a_non_boolean_flag(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();

        $resp = $this->actingAs($alice, 'api')->postJson(
            "/api/v2/auth/chat/typing/{$bob->id}",
            ['is_typing' => 'not-a-bool']
        );

        $resp->assertStatus(422);
    }
}
