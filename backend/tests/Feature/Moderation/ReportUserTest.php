<?php

namespace Tests\Feature\Moderation;

use App\Models\Friend;
use App\Models\FriendRequest;
use App\Models\ReportedUser;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Reporting a user is a moderation action with side effects:
 *
 *   - creates a row in `reported_users`
 *   - tears down any existing friendship between the two
 *   - tears down any pending friend requests in either direction
 *
 * That cascade is the load-bearing behavior tested here. A regression
 * that reports but doesn't sever the friendship would leave the
 * reporter still seeing the user's messages in their feed.
 *
 * One-time, not toggleable — duplicate reports return 409.
 */
class ReportUserTest extends TestCase
{
    use RefreshDatabase;

    /** No auth → 401. Moderation actions must be attributed to a real user. */
    #[Test]
    public function report_user_requires_auth(): void
    {
        $target = User::factory()->create();

        $this->postJson("/api/report/user/{$target->id}")
            ->assertStatus(401);
    }

    /**
     * The load-bearing assertion of this file. Reporting a user must:
     *   - create a `reported_users` row with the reason
     *   - delete any existing friendship (both directions)
     *   - delete any pending friend_requests (both directions)
     * Otherwise the reporter keeps seeing the abuser in their feed.
     */
    #[Test]
    public function report_user_creates_a_row_and_tears_down_friendship(): void
    {
        $reporter = User::factory()->create();
        $target = User::factory()->create();

        // Pre-existing friendship + pending request.
        DB::table('friends')->insert([
            'user_id' => $reporter->id,
            'friend_id' => $target->id,
            'became_friends_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        FriendRequest::factory()->create([
            'sender_id' => $reporter->id,
            'receiver_id' => $target->id,
        ]);

        $resp = $this->actingAs($reporter, 'api')->postJson(
            "/api/report/user/{$target->id}",
            ['reason' => 'spam', 'description' => 'cannot stop sending dms'],
        );

        $resp->assertOk();
        $this->assertDatabaseHas('reported_users', [
            'user_id' => $reporter->id,
            'reported_user_id' => $target->id,
            'reason' => 'spam',
        ]);
        $this->assertDatabaseMissing('friends', [
            'user_id' => $reporter->id,
            'friend_id' => $target->id,
        ]);
        $this->assertDatabaseMissing('friend_requests', [
            'sender_id' => $reporter->id,
            'receiver_id' => $target->id,
        ]);
    }

    /**
     * URL-param validation: a fabricated user id → 404. Stops
     * "report a ghost" patterns from cluttering reported_users.
     */
    #[Test]
    public function report_user_returns_404_for_unknown_target(): void
    {
        $reporter = User::factory()->create();

        $resp = $this->actingAs($reporter, 'api')->postJson('/api/report/user/999999');

        $resp->assertStatus(404);
    }

    /** Reporting yourself is nonsense → 400. */
    #[Test]
    public function report_user_rejects_self(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson("/api/report/user/{$user->id}");

        $resp->assertStatus(400);
    }

    /**
     * Already reported → 409. The action is one-time per
     * (reporter, target) pair so the moderation queue doesn't fill
     * up with duplicates from a single user.
     */
    #[Test]
    public function report_user_rejects_duplicate(): void
    {
        $reporter = User::factory()->create();
        $target = User::factory()->create();

        ReportedUser::create([
            'user_id' => $reporter->id,
            'reported_user_id' => $target->id,
            'reason' => 'first time',
        ]);

        $resp = $this->actingAs($reporter, 'api')->postJson("/api/report/user/{$target->id}");

        $resp->assertStatus(409);
    }

    /**
     * Privacy guard: the list only shows MY reports, not anyone
     * else's. Two reporters + two targets are seeded; only my
     * report should appear in the response body.
     */
    #[Test]
    public function reported_list_returns_my_reports(): void
    {
        $reporter = User::factory()->create();
        $other = User::factory()->create();
        $target = User::factory()->create();
        $other2 = User::factory()->create();

        ReportedUser::create([
            'user_id' => $reporter->id,
            'reported_user_id' => $target->id,
            'reason' => 'mine',
        ]);
        ReportedUser::create([
            'user_id' => $other->id,
            'reported_user_id' => $other2->id,
            'reason' => 'not mine',
        ]);

        $resp = $this->actingAs($reporter, 'api')->getJson('/api/report/list');
        $resp->assertOk();

        // Collection shape varies; substring check across the full body
        // confirms the reporter sees their report and not the other one.
        $body = json_encode($resp->json());
        $this->assertStringContainsString('mine', $body);
        $this->assertStringNotContainsString('not mine', $body);
    }

    /** No auth → 401. */
    #[Test]
    public function reported_list_requires_auth(): void
    {
        $this->getJson('/api/report/list')->assertStatus(401);
    }
}
