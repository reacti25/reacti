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

class GroupUpdatedEventTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function updating_group_info_as_admin_broadcasts_group_updated(): void
    {
        Event::fake([GroupUpdatedEvent::class]);

        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);

        $resp = $this->actingAs($admin, 'api')->postJson(
            "/api/auth/group/{$group->id}/update",
            [
                'name'        => 'Renamed group',
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

    #[Test]
    public function non_admin_cannot_update_group_and_no_event_fires(): void
    {
        Event::fake([GroupUpdatedEvent::class]);

        $admin   = User::factory()->create();
        $regular = User::factory()->create();

        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $group->id,
            'user_id'  => $admin->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $group->id,
            'user_id'  => $regular->id,
        ]);

        $resp = $this->actingAs($regular, 'api')->postJson(
            "/api/auth/group/{$group->id}/update",
            ['name' => 'Should be rejected'],
        );

        $resp->assertStatus(403);
        Event::assertNotDispatched(GroupUpdatedEvent::class);
    }
}
