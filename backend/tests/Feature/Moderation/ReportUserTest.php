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

class ReportUserTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function report_user_requires_auth(): void
    {
        $target = User::factory()->create();

        $this->postJson("/api/report/user/{$target->id}")
            ->assertStatus(401);
    }

    #[Test]
    public function report_user_creates_a_row_and_tears_down_friendship(): void
    {
        $reporter = User::factory()->create();
        $target   = User::factory()->create();

        // Pre-existing friendship + pending request.
        DB::table('friends')->insert([
            'user_id'           => $reporter->id,
            'friend_id'         => $target->id,
            'became_friends_at' => now(),
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);
        FriendRequest::factory()->create([
            'sender_id'   => $reporter->id,
            'receiver_id' => $target->id,
        ]);

        $resp = $this->actingAs($reporter, 'api')->postJson(
            "/api/report/user/{$target->id}",
            ['reason' => 'spam', 'description' => 'cannot stop sending dms'],
        );

        $resp->assertOk();
        $this->assertDatabaseHas('reported_users', [
            'user_id'          => $reporter->id,
            'reported_user_id' => $target->id,
            'reason'           => 'spam',
        ]);
        $this->assertDatabaseMissing('friends', [
            'user_id'   => $reporter->id,
            'friend_id' => $target->id,
        ]);
        $this->assertDatabaseMissing('friend_requests', [
            'sender_id'   => $reporter->id,
            'receiver_id' => $target->id,
        ]);
    }

    #[Test]
    public function report_user_returns_404_for_unknown_target(): void
    {
        $reporter = User::factory()->create();

        $resp = $this->actingAs($reporter, 'api')->postJson('/api/report/user/999999');

        $resp->assertStatus(404);
    }

    #[Test]
    public function report_user_rejects_self(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson("/api/report/user/{$user->id}");

        $resp->assertStatus(400);
    }

    #[Test]
    public function report_user_rejects_duplicate(): void
    {
        $reporter = User::factory()->create();
        $target   = User::factory()->create();

        ReportedUser::create([
            'user_id'          => $reporter->id,
            'reported_user_id' => $target->id,
            'reason'           => 'first time',
        ]);

        $resp = $this->actingAs($reporter, 'api')->postJson("/api/report/user/{$target->id}");

        $resp->assertStatus(409);
    }

    #[Test]
    public function reported_list_returns_my_reports(): void
    {
        $reporter = User::factory()->create();
        $other    = User::factory()->create();
        $target   = User::factory()->create();
        $other2   = User::factory()->create();

        ReportedUser::create([
            'user_id'          => $reporter->id,
            'reported_user_id' => $target->id,
            'reason'           => 'mine',
        ]);
        ReportedUser::create([
            'user_id'          => $other->id,
            'reported_user_id' => $other2->id,
            'reason'           => 'not mine',
        ]);

        $resp = $this->actingAs($reporter, 'api')->getJson('/api/report/list');
        $resp->assertOk();

        // The reporter only sees their own reports.
        $reasons = collect($resp->json('data.data'))->pluck('reason')->all();
        $this->assertContains('mine', $reasons);
        $this->assertNotContains('not mine', $reasons);
    }

    #[Test]
    public function reported_list_requires_auth(): void
    {
        $this->getJson('/api/report/list')->assertStatus(401);
    }
}
