<?php

namespace Tests\Feature\Friends;

use App\Models\FriendRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Being able to become friends AGAIN after unfriending or declining.
 *
 * Achia, 2026-08-27: sending a request from one test account to another
 * answered "Friend request already exists", while the receiving account's list
 * was empty. A dead end with nothing visible to clear.
 *
 * Rows in `friend_requests` are never removed — accepting sets 'accepted',
 * declining sets 'declined' — and `sendRequest` treated ANY row in either
 * direction as a duplicate. Unfriending deleted the friendship but left the
 * accepted row behind. So:
 *
 *   - two people who unfriended could NEVER be friends again, and
 *   - a declined request blocked that person from ever asking again,
 *
 * while the receiver saw nothing, because their list only shows pending rows.
 */
class RefriendTest extends TestCase
{
    use RefreshDatabase;

    /** Accepts a request from $a to $b, leaving them friends. */
    private function befriend(User $a, User $b): void
    {
        $this->actingAs($a, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $b->id])
            ->assertSuccessful();

        $this->actingAs($b, 'api')
            ->postJson('/api/friends/accept-request', ['sender_id' => $a->id])
            ->assertSuccessful();
    }

    /** The exact sequence Achia hit: befriend, unfriend, try again. */
    #[Test]
    public function two_people_can_be_friends_again_after_unfriending(): void
    {
        $testi = User::factory()->create();
        $testo = User::factory()->create();

        $this->befriend($testi, $testo);

        $this->actingAs($testi, 'api')
            ->deleteJson("/api/friends/unfriend/{$testo->id}")
            ->assertSuccessful();

        // This answered 409 "Friend request already exists" forever.
        $this->actingAs($testi, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $testo->id])
            ->assertSuccessful();

        // ...and the receiver can actually SEE it, which is the half that made
        // the old behaviour so confusing: the sender was told a request
        // existed while the receiver's list stayed empty.
        $this->actingAs($testo, 'api')
            ->getJson('/api/friends/requests')
            ->assertOk()
            ->assertJsonPath('data.requests.0.person.id', $testi->id);
    }

    /** Unfriending clears the request row, not just the friendship. */
    #[Test]
    public function unfriending_clears_the_request_history(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $this->befriend($a, $b);

        $this->actingAs($b, 'api')
            ->deleteJson("/api/friends/unfriend/{$a->id}")
            ->assertSuccessful();

        // Either direction — the pair is what matters, not who asked.
        $this->assertSame(0, FriendRequest::where('sender_id', $a->id)
            ->where('receiver_id', $b->id)->count());
        $this->assertSame(0, DB::table('friends')->count());
    }

    /** A declined request must not silence someone forever. */
    #[Test]
    public function a_declined_request_can_be_sent_again(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();

        $this->actingAs($a, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $b->id])
            ->assertSuccessful();
        $this->actingAs($b, 'api')
            ->postJson('/api/friends/decline-request', ['sender_id' => $a->id])
            ->assertSuccessful();

        // People change their minds. A single "no" used to be permanent, and
        // invisibly so.
        $this->actingAs($a, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $b->id])
            ->assertSuccessful();
    }

    /** Settled rows are cleared, so history cannot pile up per pair. */
    #[Test]
    public function a_second_round_leaves_only_one_row(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();

        $this->actingAs($a, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $b->id]);
        $this->actingAs($b, 'api')
            ->postJson('/api/friends/decline-request', ['sender_id' => $a->id]);
        $this->actingAs($a, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $b->id]);

        $this->assertSame(1, FriendRequest::count());
    }

    /** A request that IS still pending must still be refused. */
    #[Test]
    public function a_pending_request_still_blocks_a_duplicate(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();

        $this->actingAs($a, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $b->id])
            ->assertSuccessful();

        // The rule this whole change relaxes still has to hold where it should.
        $this->actingAs($a, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $b->id])
            ->assertStatus(409);
    }

    /** Asking someone who is already a friend says so, in those words. */
    #[Test]
    public function already_friends_says_already_friends(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $this->befriend($a, $b);

        // "Friend request already exists" sent people hunting for a request
        // that was not there.
        $this->actingAs($b, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $a->id])
            ->assertStatus(409)
            ->assertJsonPath('message', 'You are already friends with this user.');
    }
}
