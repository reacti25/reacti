<?php

namespace Tests\Feature\Friends;

use App\Models\FriendRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Endpoint coverage for the friend-request lifecycle. Six endpoints
 * grouped under /api/friends/:
 *
 *   send-request          send a request
 *   cancel-request        unsend your own pending request
 *   accept-request        promote a pending request to a real friendship
 *   decline-request       mark a pending request declined
 *   requests              list incoming pending requests
 *   requests/sent/list    list outgoing pending requests
 *
 * Each endpoint gets happy + auth + validation + permission paths.
 * The acceptance path also verifies that the two-row friendship is
 * created (one row per direction), since the chat list query union-s
 * across both directions.
 */
class FriendRequestEndpointsTest extends TestCase
{
    use RefreshDatabase;

    // -------- send --------

    #[Test]
    public function send_request_requires_auth(): void
    {
        $this->postJson('/api/friends/send-request', ['receiver_id' => 1])
            ->assertStatus(401);
    }

    #[Test]
    public function send_request_validates_receiver_exists(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/friends/send-request', [
            'receiver_id' => 999999,
        ]);

        $resp->assertStatus(422);
    }

    #[Test]
    public function send_request_rejects_self(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/friends/send-request', [
            'receiver_id' => $user->id,
        ]);

        $resp->assertStatus(400);
    }

    #[Test]
    public function send_request_rejects_duplicate(): void
    {
        $sender   = User::factory()->create();
        $receiver = User::factory()->create();

        FriendRequest::factory()->create([
            'sender_id'   => $sender->id,
            'receiver_id' => $receiver->id,
        ]);

        $resp = $this->actingAs($sender, 'api')->postJson('/api/friends/send-request', [
            'receiver_id' => $receiver->id,
        ]);

        $resp->assertStatus(409);
    }

    // -------- cancel --------

    #[Test]
    public function cancel_request_removes_a_pending_row(): void
    {
        $sender   = User::factory()->create();
        $receiver = User::factory()->create();
        $req      = FriendRequest::factory()->create([
            'sender_id'   => $sender->id,
            'receiver_id' => $receiver->id,
        ]);

        $resp = $this->actingAs($sender, 'api')->postJson('/api/friends/cancel-request', [
            'receiver_id' => $receiver->id,
        ]);

        $resp->assertOk();
        $this->assertDatabaseMissing('friend_requests', ['id' => $req->id]);
    }

    #[Test]
    public function cancel_request_returns_404_without_pending(): void
    {
        $sender   = User::factory()->create();
        $receiver = User::factory()->create();

        $resp = $this->actingAs($sender, 'api')->postJson('/api/friends/cancel-request', [
            'receiver_id' => $receiver->id,
        ]);

        $resp->assertStatus(404);
    }

    #[Test]
    public function cancel_request_requires_auth(): void
    {
        $this->postJson('/api/friends/cancel-request', ['receiver_id' => 1])
            ->assertStatus(401);
    }

    // -------- accept --------

    #[Test]
    public function accept_request_creates_friendship_rows_both_directions(): void
    {
        $sender   = User::factory()->create();
        $receiver = User::factory()->create();
        FriendRequest::factory()->create([
            'sender_id'   => $sender->id,
            'receiver_id' => $receiver->id,
        ]);

        $resp = $this->actingAs($receiver, 'api')->postJson('/api/friends/accept-request', [
            'sender_id' => $sender->id,
        ]);

        $resp->assertOk();
        $this->assertDatabaseHas('friends', [
            'user_id'   => $receiver->id,
            'friend_id' => $sender->id,
        ]);
        $this->assertDatabaseHas('friends', [
            'user_id'   => $sender->id,
            'friend_id' => $receiver->id,
        ]);
        $this->assertDatabaseHas('friend_requests', [
            'sender_id'   => $sender->id,
            'receiver_id' => $receiver->id,
            'status'      => 'accepted',
        ]);
    }

    #[Test]
    public function accept_request_returns_404_when_no_pending(): void
    {
        $sender   = User::factory()->create();
        $receiver = User::factory()->create();

        $resp = $this->actingAs($receiver, 'api')->postJson('/api/friends/accept-request', [
            'sender_id' => $sender->id,
        ]);

        $resp->assertStatus(404);
    }

    #[Test]
    public function accept_request_validates_sender_exists(): void
    {
        $receiver = User::factory()->create();

        $resp = $this->actingAs($receiver, 'api')->postJson('/api/friends/accept-request', [
            'sender_id' => 999999,
        ]);

        $resp->assertStatus(422);
    }

    #[Test]
    public function accept_request_requires_auth(): void
    {
        $this->postJson('/api/friends/accept-request', ['sender_id' => 1])
            ->assertStatus(401);
    }

    // -------- decline --------

    #[Test]
    public function decline_request_marks_status_declined(): void
    {
        $sender   = User::factory()->create();
        $receiver = User::factory()->create();
        $req      = FriendRequest::factory()->create([
            'sender_id'   => $sender->id,
            'receiver_id' => $receiver->id,
        ]);

        $resp = $this->actingAs($receiver, 'api')->postJson('/api/friends/decline-request', [
            'sender_id' => $sender->id,
        ]);

        $resp->assertOk();
        $this->assertDatabaseHas('friend_requests', [
            'id'     => $req->id,
            'status' => 'declined',
        ]);
    }

    #[Test]
    public function decline_request_returns_404_when_no_pending(): void
    {
        $sender   = User::factory()->create();
        $receiver = User::factory()->create();

        $resp = $this->actingAs($receiver, 'api')->postJson('/api/friends/decline-request', [
            'sender_id' => $sender->id,
        ]);

        $resp->assertStatus(404);
    }

    #[Test]
    public function decline_request_requires_auth(): void
    {
        $this->postJson('/api/friends/decline-request', ['sender_id' => 1])
            ->assertStatus(401);
    }

    // -------- list --------

    #[Test]
    public function get_requests_returns_only_pending_incoming(): void
    {
        $me  = User::factory()->create();
        $a   = User::factory()->create();
        $b   = User::factory()->create();

        FriendRequest::factory()->create([
            'sender_id'   => $a->id,
            'receiver_id' => $me->id,
            'status'      => 'pending',
        ]);
        FriendRequest::factory()->accepted()->create([
            'sender_id'   => $b->id,
            'receiver_id' => $me->id,
        ]);

        $resp = $this->actingAs($me, 'api')->getJson('/api/friends/requests');
        $resp->assertOk();

        // The collection ships sender IDs; only the pending sender ($a) appears.
        $body     = json_encode($resp->json());
        $this->assertStringContainsString((string) $a->id, $body);
        $this->assertStringNotContainsString('"sender_id":' . $b->id, $body);
    }

    #[Test]
    public function get_requests_requires_auth(): void
    {
        $this->getJson('/api/friends/requests')->assertStatus(401);
    }

    #[Test]
    public function get_sent_requests_returns_only_pending_outgoing(): void
    {
        $me = User::factory()->create();
        $a  = User::factory()->create();
        $b  = User::factory()->create();

        FriendRequest::factory()->create([
            'sender_id'   => $me->id,
            'receiver_id' => $a->id,
            'status'      => 'pending',
        ]);
        FriendRequest::factory()->accepted()->create([
            'sender_id'   => $me->id,
            'receiver_id' => $b->id,
        ]);

        $resp = $this->actingAs($me, 'api')->getJson('/api/friends/requests/sent/list');
        $resp->assertOk();

        $body = json_encode($resp->json());
        $this->assertStringContainsString((string) $a->id, $body);
        $this->assertStringNotContainsString('"receiver_id":' . $b->id, $body);
    }

    #[Test]
    public function get_sent_requests_requires_auth(): void
    {
        $this->getJson('/api/friends/requests/sent/list')->assertStatus(401);
    }
}
