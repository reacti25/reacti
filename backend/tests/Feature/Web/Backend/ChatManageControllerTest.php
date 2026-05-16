<?php

namespace Tests\Feature\Web\Backend;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * ChatManageController — the 1:1 chat surface of the admin panel,
 * mounted under `/admin/chat/*` (see routes/backend.php). The acting
 * admin plays the "sender" role; the other party is any user.
 *
 * Routes exercised here:
 *   GET  /admin/chat/                       index   (Blade view)
 *   GET  /admin/chat/list                   list    (JSON)
 *   GET  /admin/chat/search                 search  (JSON)
 *   GET  /admin/chat/conversation/{id}      conversation (JSON)
 *   POST /admin/chat/send/{id}              send    (JSON)
 *   GET  /admin/chat/seen/all/{id}          seenAll (JSON)
 *   GET  /admin/chat/seen/single/{chatId}   seenSingle (JSON)
 *   GET  /admin/chat/room/{id}              room    (JSON) — see the
 *                                           guard-mismatch test below
 *
 * Admin-middleware behavior (guest/non-admin) is covered once by
 * [[AdminMiddlewareTest]] and not repeated per endpoint.
 */
class ChatManageControllerTest extends TestCase
{
    use RefreshDatabase;

    /** The `backend.app` layout pulls in @vite; stub it for view tests. */
    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    /** Convenience: a fresh admin user for the acting session. */
    private function admin(): User
    {
        return User::factory()->create(['role' => 'admin']);
    }

    /** `index` renders the `backend.layouts.chat.index` Blade view. */
    #[Test]
    public function index_renders_the_chat_view(): void
    {
        $resp = $this->actingAs($this->admin())->get('/admin/chat');

        $resp->assertOk()
            ->assertViewIs('backend.layouts.chat.index');
    }

    /**
     * `list` returns every user the admin has exchanged a message with
     * (in either direction) and excludes users with no shared history.
     */
    #[Test]
    public function list_returns_only_users_with_a_shared_conversation(): void
    {
        $admin     = $this->admin();
        $partner   = User::factory()->create();
        $stranger  = User::factory()->create();

        // One message admin -> partner gives them a shared history.
        $room = Room::factory()->between($admin, $partner)->create();
        Chat::factory()->create([
            'sender_id'   => $admin->id,
            'receiver_id' => $partner->id,
            'room_id'     => $room->id,
        ]);

        $resp = $this->actingAs($admin)->getJson('/admin/chat/list');

        $resp->assertOk()->assertJsonPath('success', true);

        $ids = collect($resp->json('data.users'))->pluck('id')->all();
        $this->assertContains($partner->id, $ids);
        $this->assertNotContains($stranger->id, $ids, 'A user with no shared chat must not appear.');
        $this->assertNotContains($admin->id, $ids, 'The admin must not list themself.');
    }

    /**
     * `search` matches the keyword against first name, last name, or
     * email, and never returns the acting admin.
     */
    #[Test]
    public function search_matches_users_by_name_and_excludes_self(): void
    {
        $admin = $this->admin();
        $match = User::factory()->create(['first_name' => 'Zephyrine']);
        User::factory()->create(['first_name' => 'Quentin']);

        $resp = $this->actingAs($admin)->getJson('/admin/chat/search?keyword=Zephyr');

        $resp->assertOk();
        $ids = collect($resp->json('data.users'))->pluck('id')->all();
        $this->assertContains($match->id, $ids);
        $this->assertNotContains($admin->id, $ids);
    }

    /**
     * `conversation` returns the messages between the admin and the
     * other user, and as a side effect flips the other user's
     * messages to status `read`.
     *
     * The room is seeded as (user_one = partner, user_two = admin)
     * on purpose: `conversation`'s room lookup only matches that exact
     * column order. Seeding it any other way would send the
     * controller down its room-create branch, which inserts a row
     * with a null `user_one_id` and 500s — out of scope for this test.
     */
    #[Test]
    public function conversation_returns_messages_and_marks_incoming_as_read(): void
    {
        $admin   = $this->admin();
        $partner = User::factory()->create();
        $room    = Room::create([
            'user_one_id' => $partner->id,
            'user_two_id' => $admin->id,
        ]);

        $incoming = Chat::factory()->create([
            'sender_id'   => $partner->id,
            'receiver_id' => $admin->id,
            'room_id'     => $room->id,
            'status'      => 'sent',
        ]);

        $resp = $this->actingAs($admin)->getJson("/admin/chat/conversation/{$partner->id}");

        $resp->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonCount(1, 'data.chat');

        $this->assertDatabaseHas('chats', [
            'id'     => $incoming->id,
            'status' => 'read',
        ]);
    }

    /**
     * `send` with a text body creates a chat row, opens a room if none
     * exists, and echoes the new message back.
     */
    #[Test]
    public function send_creates_a_text_message_and_a_room(): void
    {
        $admin   = $this->admin();
        $partner = User::factory()->create();

        $resp = $this->actingAs($admin)->postJson("/admin/chat/send/{$partner->id}", [
            'text' => 'Hello from the admin panel',
        ]);

        $resp->assertOk()->assertJsonPath('success', true);

        $this->assertDatabaseHas('chats', [
            'sender_id'   => $admin->id,
            'receiver_id' => $partner->id,
            'text'        => 'Hello from the admin panel',
            'status'      => 'sent',
        ]);
        // `send` opens the room as (user_one = sender, user_two = receiver).
        $this->assertDatabaseHas('rooms', [
            'user_one_id' => $admin->id,
            'user_two_id' => $partner->id,
        ]);
    }

    /** A text body over 1000 chars fails validation with 422. */
    #[Test]
    public function send_rejects_an_overlong_text_body(): void
    {
        $admin   = $this->admin();
        $partner = User::factory()->create();

        $resp = $this->actingAs($admin)->postJson("/admin/chat/send/{$partner->id}", [
            'text' => str_repeat('a', 1001),
        ]);

        $resp->assertStatus(422);
        $this->assertDatabaseEmpty('chats');
    }

    /**
     * Sending to a non-existent user (or to yourself) is reported as a
     * soft failure: `success: false`, HTTP 200, and no chat row. The
     * controller deliberately doesn't 404 here.
     */
    #[Test]
    public function send_to_missing_user_is_a_soft_failure(): void
    {
        $admin = $this->admin();

        $resp = $this->actingAs($admin)->postJson('/admin/chat/send/999999', [
            'text' => 'into the void',
        ]);

        $resp->assertOk()->assertJsonPath('success', false);
        $this->assertDatabaseEmpty('chats');
    }

    /** `seenAll` flips every incoming message from one user to `read`. */
    #[Test]
    public function seen_all_marks_every_incoming_message_read(): void
    {
        $admin   = $this->admin();
        $partner = User::factory()->create();
        $room    = Room::factory()->between($admin, $partner)->create();

        Chat::factory()->count(3)->create([
            'sender_id'   => $partner->id,
            'receiver_id' => $admin->id,
            'room_id'     => $room->id,
            'status'      => 'sent',
        ]);

        $this->actingAs($admin)->getJson("/admin/chat/seen/all/{$partner->id}")
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertSame(
            0,
            Chat::where('receiver_id', $admin->id)->where('status', '!=', 'read')->count(),
        );
    }

    /** `seenSingle` flips exactly one chat (by id) to `read`. */
    #[Test]
    public function seen_single_marks_one_message_read(): void
    {
        $admin   = $this->admin();
        $partner = User::factory()->create();
        $room    = Room::factory()->between($admin, $partner)->create();

        $chat = Chat::factory()->create([
            'sender_id'   => $partner->id,
            'receiver_id' => $admin->id,
            'room_id'     => $room->id,
            'status'      => 'sent',
        ]);

        $this->actingAs($admin)->getJson("/admin/chat/seen/single/{$chat->id}")
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertDatabaseHas('chats', ['id' => $chat->id, 'status' => 'read']);
    }

    /**
     * KNOWN BUG (documented, not fixed — testing-only scope).
     *
     * `room()` resolves the current user with `Auth::guard('api')->id()`,
     * but this route lives in the *web* admin panel where the session
     * is on the default (web) guard. The api guard has no user, so
     * `$sender_id` is null and the controller tries to
     * `Room::create(['user_one_id' => null, ...])` — a NOT NULL foreign
     * key — which throws a QueryException surfaced as HTTP 500.
     *
     * The fix would be `Auth::id()` (web guard), matching every other
     * method in this controller. Until that lands, this test pins the
     * broken behavior so a future fix is noticed (it will start
     * failing and should then be rewritten to expect 200).
     */
    #[Test]
    public function room_endpoint_is_broken_under_the_web_admin_guard(): void
    {
        $admin   = $this->admin();
        $partner = User::factory()->create();

        $resp = $this->actingAs($admin)->getJson("/admin/chat/room/{$partner->id}");

        $this->assertNotEquals(200, $resp->status(), 'If this now returns 200 the api-guard bug was fixed — update this test to expect success.');
    }
}
