<?php

namespace Tests\Feature\Analytics;

use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\GroupMessageUserStatus;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * GET /api/internal/insights: the database half of the Insights dashboard.
 * Guarded by a shared token; returns anonymous journeys whose flags the
 * dashboard's product numbers are counted from.
 */
class InsightsEndpointTest extends TestCase
{
    use RefreshDatabase;

    private function fetch(string $token = 'secret')
    {
        return $this->getJson('/api/internal/insights', ['Authorization' => "Bearer $token"]);
    }

    /** The journey row for a user, found by join date + order (rows carry no id). */
    private function rowFor(User $user): array
    {
        $ids = User::where('role', 'user')->orderBy('id')->pluck('id')->all();

        return $this->fetch()->json('data.users')[array_search($user->id, $ids)];
    }

    #[Test]
    public function route_does_not_exist_until_a_token_is_configured(): void
    {
        config(['analytics.insights_token' => null]);

        $this->fetch()->assertNotFound();
    }

    #[Test]
    public function wrong_or_missing_token_is_refused(): void
    {
        config(['analytics.insights_token' => 'secret']);

        $this->fetch('nope')->assertUnauthorized();
        $this->getJson('/api/internal/insights')->assertUnauthorized();
    }

    #[Test]
    public function private_reacti_reports_opened_reacted_and_watched(): void
    {
        config(['analytics.insights_token' => 'secret']);
        $reacti = Chat::factory()->blurredMedia()->viewed()->create(['created_at' => '2026-10-01 10:00:00']);
        Chat::factory()->create([ // the reaction, watched by the original sender
            'sender_id' => $reacti->receiver_id, 'receiver_id' => $reacti->sender_id, 'room_id' => $reacti->room_id,
            'message_type' => 'reaction', 'file' => 'r.mp4', 'reply_to_id' => $reacti->id, 'is_viewed' => true,
        ]);
        Chat::factory()->blurredMedia()->create(['sender_id' => $reacti->sender_id, 'created_at' => '2026-10-03 10:00:00']);
        Chat::factory()->create(['sender_id' => $reacti->sender_id]); // text: not a Reacti

        $sender = $this->rowFor(User::find($reacti->sender_id));
        $this->assertSame([['2026-10-01', 1, 1, 1], ['2026-10-03', 0, 0, 0]], $sender['sent']);
        $this->assertNull($sender['first_received']);

        $recipient = $this->rowFor(User::find($reacti->receiver_id));
        $this->assertSame([], $recipient['sent'], 'a reaction is not a Reacti');
        $this->assertSame('2026-10-01', $recipient['first_received']);
    }

    #[Test]
    public function group_reacti_counts_other_members_and_the_senders_watch(): void
    {
        config(['analytics.insights_token' => 'secret']);
        [$sender, $member] = User::factory()->count(2)->create();
        $group = Group::factory()->create();
        $reacti = GroupMessage::factory()->withMedia()->create(['group_id' => $group->id, 'sender_id' => $sender->id, 'created_at' => '2026-10-02 09:00:00']);
        // The sender's own row is created viewed; it must not count as "opened".
        GroupMessageUserStatus::insert([
            ['message_id' => $reacti->id, 'user_id' => $sender->id, 'is_viewed' => true, 'is_blurred' => false],
            ['message_id' => $reacti->id, 'user_id' => $member->id, 'is_viewed' => false, 'is_blurred' => true],
        ]);
        $this->assertSame([['2026-10-02', 0, 0, 0]], $this->rowFor($sender)['sent']);

        GroupMessageUserStatus::where('user_id', $member->id)->update(['is_viewed' => true]);
        $reaction = GroupMessage::factory()->reaction()->create(['group_id' => $group->id, 'sender_id' => $member->id, 'reply_to_message_id' => $reacti->id]);
        GroupMessageUserStatus::insert(['message_id' => $reaction->id, 'user_id' => $sender->id, 'is_viewed' => false, 'is_blurred' => false]);
        $this->assertSame([['2026-10-02', 1, 1, 0]], $this->rowFor($sender)['sent']);

        GroupMessageUserStatus::where(['message_id' => $reaction->id, 'user_id' => $sender->id])->update(['is_viewed' => true]);
        $this->assertSame([['2026-10-02', 1, 1, 1]], $this->rowFor($sender)['sent']);
        $this->assertSame('2026-10-02', $this->rowFor($member)['first_received']);
    }

    #[Test]
    public function admins_are_left_out_and_rows_carry_no_identity(): void
    {
        config(['analytics.insights_token' => 'secret']);
        User::factory()->create(['role' => 'admin']);
        User::factory()->create(['created_at' => '2026-09-01 12:00:00']);

        $rows = $this->fetch()->assertOk()->assertJsonPath('success', true)->json('data.users');
        $this->assertCount(1, $rows);
        $this->assertSame(['joined' => '2026-09-01', 'sent' => [], 'first_received' => null], $rows[0]);
    }
}
