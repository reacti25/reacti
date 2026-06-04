<?php

namespace Tests\Feature\Events;

use App\Events\GroupUpdatedEvent;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Group-info changes (name, description, avatar) must broadcast a
 * GroupUpdatedEvent so member clients re-render the group header
 * without polling.
 *
 * Two paths matter:
 *   - admin updates → event fires with payload describing the change
 *   - non-admin tries → 403 + no event (don't tell listeners about a
 *     change that didn't happen)
 */
class GroupUpdatedEventTest extends TestCase
{
    use RefreshDatabase;

    /**
     * The admin path. The payload should carry the new name/description
     * AND who made the change — clients use `updated_by` to show "Alice
     * renamed the group" without an extra API round trip.
     */
    #[Test]
    public function updating_group_info_as_admin_broadcasts_group_updated(): void
    {
        Event::fake([GroupUpdatedEvent::class]);

        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $admin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/update",
            [
                'name' => 'Renamed group',
                'description' => 'New description',
            ],
        );

        $resp->assertOk();
        $resp->assertJsonPath('success', true);

        Event::assertDispatched(
            GroupUpdatedEvent::class,
            fn (GroupUpdatedEvent $event): bool => (int) $event->roomId === $group->id
                && $event->updateType === 'info'
                && ($event->data['name'] ?? null) === 'Renamed group'
                && (int) ($event->data['updated_by'] ?? 0) === $admin->id,
        );
        Event::assertDispatchedTimes(GroupUpdatedEvent::class, 1);
    }

    /**
     * Non-admins are blocked at the controller (403) and crucially the
     * broadcast does *not* fire. A regression that broadcasts before
     * the permission check would let any group member trigger
     * spurious GroupUpdatedEvents that other members would believe.
     */
    #[Test]
    public function non_admin_cannot_update_group_and_no_event_fires(): void
    {
        Event::fake([GroupUpdatedEvent::class]);

        $admin = User::factory()->create();
        $regular = User::factory()->create();

        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id' => $admin->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id' => $regular->id,
        ]);

        $resp = $this->actingAs($regular, 'api')->postJson(
            "/api/auth/group/{$group->id}/update",
            ['name' => 'Should be rejected'],
        );

        $resp->assertStatus(403);
        Event::assertNotDispatched(GroupUpdatedEvent::class);
    }
}
