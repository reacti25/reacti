<?php

namespace Tests\Feature\Friends;

use App\Models\User;
use App\Services\FriendRequestService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Caps on how many friend requests one account may send.
 *
 * The other half of the discovery model (see UsernameSearchModelTest).
 * Narrowing *who* can be found is only ever half a defence: anyone who finds a
 * way to enumerate accounts still has to send the requests one at a time, and
 * this is where that stops. It is also the part Instagram actually relies on —
 * roughly twenty follows an hour before it starts saying no.
 *
 * Counted from the table rather than a cache key on purpose: a cache flush or a
 * restart must not hand someone a fresh allowance.
 */
class FriendRequestLimitTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Seeds [$count] already-sent requests from [$sender], aged [$ageHours].
     *
     * Each needs a distinct receiver: a duplicate pair is rejected earlier by
     * the "request already exists" rule, which would mask the limit entirely.
     */
    private function seedSent(User $sender, int $count, float $ageHours = 0, string $status = 'pending'): void
    {
        // Inserted through the query builder, not Eloquent: `create()` stamps
        // its own timestamps and silently discards the ages passed here, which
        // made every seeded row look like it was sent this second.
        $at = now()->subHours($ageHours);
        for ($i = 0; $i < $count; $i++) {
            DB::table('friend_requests')->insert([
                'sender_id' => $sender->id,
                'receiver_id' => User::factory()->create()->id,
                'status' => $status,
                'created_at' => $at,
                'updated_at' => $at,
            ]);
        }
    }

    /** Under the cap, a request goes through as before. */
    #[Test]
    public function a_normal_request_is_unaffected(): void
    {
        $sender = User::factory()->create();
        $target = User::factory()->create();

        $this->actingAs($sender, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $target->id])
            ->assertSuccessful();
    }

    /** The hourly cap answers 429 rather than silently dropping the request. */
    #[Test]
    public function the_hourly_cap_blocks_the_next_request(): void
    {
        $sender = User::factory()->create();
        $this->seedSent($sender, FriendRequestService::MAX_REQUESTS_PER_HOUR);
        $target = User::factory()->create();

        $this->actingAs($sender, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $target->id])
            ->assertStatus(429);
    }

    /** An hour later the allowance is back — this is a cap, not a ban. */
    #[Test]
    public function the_hourly_cap_lets_go_once_the_hour_has_passed(): void
    {
        $sender = User::factory()->create();
        $this->seedSent($sender, FriendRequestService::MAX_REQUESTS_PER_HOUR, ageHours: 2);
        $target = User::factory()->create();

        $this->actingAs($sender, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $target->id])
            ->assertSuccessful();
    }

    /** Spread thin across the day, the daily cap still catches it. */
    #[Test]
    public function the_daily_cap_blocks_even_when_the_hour_is_clear(): void
    {
        $sender = User::factory()->create();
        // Old enough that the hourly window is empty, recent enough to count
        // toward the day — otherwise the hourly cap would be doing the work and
        // this would prove nothing.
        $this->seedSent($sender, FriendRequestService::MAX_REQUESTS_PER_DAY, ageHours: 5);
        $target = User::factory()->create();

        $this->actingAs($sender, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $target->id])
            ->assertStatus(429);
    }

    /** Being turned down repeatedly tightens the cap. */
    #[Test]
    public function repeated_declines_cut_the_daily_allowance(): void
    {
        $sender = User::factory()->create();
        // Enough declines to trigger the back-off, plus a number of sends that
        // sits under the normal daily cap but over the reduced one. Nobody has
        // to report them: the people receiving the requests already said no.
        $this->seedSent($sender, FriendRequestService::REJECTED_BACKOFF_THRESHOLD, ageHours: 5, status: 'declined');
        $this->seedSent($sender, FriendRequestService::BACKED_OFF_DAILY_LIMIT, ageHours: 5);
        $target = User::factory()->create();

        $this->actingAs($sender, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $target->id])
            ->assertStatus(429);
    }

    /** Without the declines, that same volume is fine. */
    #[Test]
    public function the_same_volume_is_allowed_without_declines(): void
    {
        $sender = User::factory()->create();
        $this->seedSent($sender, FriendRequestService::BACKED_OFF_DAILY_LIMIT, ageHours: 5);
        $target = User::factory()->create();

        $this->actingAs($sender, 'api')
            ->postJson('/api/friends/send-request', ['receiver_id' => $target->id])
            ->assertSuccessful();
    }
}
