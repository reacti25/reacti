<?php

namespace Tests\Feature\Group;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Regression guard for the "my group messages vanish" bug.
 *
 * The group thread orders messages `created_at ASC` and the app fetches it
 * with no `per_page` and never loads later pages. With the old default of 50
 * the app only ever saw the OLDEST 50 messages, so once a group passed 50
 * messages every recent message — including the user's own sends — was on
 * page 2+ and never downloaded (it "vanished" from the thread). The default
 * now returns the whole thread (parity with the 1:1 endpoint).
 *
 * RED before the fix (default 50 dropped the newest), GREEN after.
 */
class GroupThreadPaginationTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function the_default_fetch_returns_recent_messages_past_the_first_fifty(): void
    {
        $member = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $member->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $member->id,
        ]);

        // 50 older messages, well in the past so ASC ordering is deterministic.
        for ($i = 0; $i < 50; $i++) {
            GroupMessage::factory()->create([
                'group_id' => $group->id,
                'sender_id' => $member->id,
                'text' => "old #$i",
                'created_at' => now()->subDays(2)->addMinutes($i),
            ]);
        }

        // The user's just-sent message — newest in a 51-message group.
        GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $member->id,
            'text' => 'MY-LATEST-MESSAGE',
            'created_at' => now(),
        ]);

        // Exactly how the app calls it: no per_page, page 1.
        $resp = $this->actingAs($member, 'api')
            ->getJson("/api/auth/group/{$group->id}/messages");

        $resp->assertOk();
        // The sender's newest message must be present (was dropped before the fix),
        // and the oldest is still there too.
        $resp->assertJsonFragment(['text' => 'MY-LATEST-MESSAGE']);
        $resp->assertJsonFragment(['text' => 'old #0']);
    }

    /**
     * Seed a group with [$count] sequential messages (m0..m{n-1}, m{n-1} newest)
     * and return [member, group].
     *
     * @return array{0: User, 1: Group}
     */
    private function groupWithMessages(int $count): array
    {
        $member = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $member->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $member->id,
        ]);

        for ($i = 0; $i < $count; $i++) {
            GroupMessage::factory()->create([
                'group_id' => $group->id,
                'sender_id' => $member->id,
                'text' => "m$i",
                'created_at' => now()->subMinutes($count - $i),
            ]);
        }

        return [$member, $group];
    }

    #[Test]
    public function cursor_mode_returns_the_newest_page_with_has_more(): void
    {
        [$member, $group] = $this->groupWithMessages(100);

        $resp = $this->actingAs($member, 'api')
            ->getJson("/api/auth/group/{$group->id}/messages?limit=30");

        $resp->assertOk();
        $resp->assertJsonCount(30, 'data.messages');
        $resp->assertJsonPath('data.pagination.has_more', true);
        // Newest is present (newest-first), and a message from an older page is not.
        $resp->assertJsonPath('data.messages.0.text', 'm99');
        $resp->assertJsonFragment(['text' => 'm70']); // 30th-newest, still on page 1
        $resp->assertJsonMissing(['text' => 'm69']);   // first of the next older page
    }

    #[Test]
    public function cursor_before_returns_the_next_older_page_without_overlap(): void
    {
        [$member, $group] = $this->groupWithMessages(100);

        // m70 is the oldest on the newest page; page older than it starts at m69.
        $before = GroupMessage::where('group_id', $group->id)
            ->where('text', 'm70')->value('id');

        $resp = $this->actingAs($member, 'api')
            ->getJson("/api/auth/group/{$group->id}/messages?limit=30&before={$before}");

        $resp->assertOk();
        $resp->assertJsonCount(30, 'data.messages');
        $resp->assertJsonPath('data.messages.0.text', 'm69'); // newest of the older page
        $resp->assertJsonFragment(['text' => 'm40']);          // 30 older: m69..m40
        $resp->assertJsonMissing(['text' => 'm70']);           // no overlap with page 1
        $resp->assertJsonMissing(['text' => 'm99']);
        $resp->assertJsonPath('data.pagination.has_more', true);
    }

    #[Test]
    public function cursor_mode_reports_end_of_history(): void
    {
        [$member, $group] = $this->groupWithMessages(5);

        $resp = $this->actingAs($member, 'api')
            ->getJson("/api/auth/group/{$group->id}/messages?limit=30");

        $resp->assertOk();
        $resp->assertJsonCount(5, 'data.messages');
        $resp->assertJsonPath('data.pagination.has_more', false);
    }

    #[Test]
    public function cursor_limit_is_clamped_to_a_max(): void
    {
        [$member, $group] = $this->groupWithMessages(150);

        $resp = $this->actingAs($member, 'api')
            ->getJson("/api/auth/group/{$group->id}/messages?limit=99999");

        $resp->assertOk();
        // Clamped to 100, not the requested 99999.
        $count = count($resp->json('data.messages'));
        $this->assertSame(100, $count);
    }

    #[Test]
    public function the_no_param_response_keeps_the_full_pagination_shape(): void
    {
        // Back-compat guard: the live app's call (no params) still gets the
        // total/current_page/last_page/per_page block it has always received.
        [$member, $group] = $this->groupWithMessages(3);

        $resp = $this->actingAs($member, 'api')
            ->getJson("/api/auth/group/{$group->id}/messages");

        $resp->assertOk();
        $resp->assertJsonStructure([
            'data' => [
                'pagination' => ['total', 'current_page', 'last_page', 'per_page'],
            ],
        ]);
    }
}
