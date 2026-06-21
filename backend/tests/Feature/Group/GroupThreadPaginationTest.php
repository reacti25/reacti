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
}
