<?php

namespace Tests\Feature\Services;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use App\Services\AdminChatService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins the admin chat list's JSON shape. The admin panel's JavaScript reads
 * `value.last_chat.short_text` and `value.last_chat.humanize_date`
 * (resources/views/backend/layouts/chat/index.blade.php). `last_chat` moved
 * from an ad-hoc attribute to setRelation() (PHPStan 2.3 fix, #467); this
 * proves it still serialises under the same key with the same fields.
 */
class AdminChatPartnersTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function each_partner_carries_its_last_chat_with_the_fields_the_admin_page_reads(): void
    {
        $admin = User::factory()->create();
        $partner = User::factory()->create();
        $room = Room::factory()->between($admin, $partner)->create();
        Chat::factory()->create([
            'sender_id' => $partner->id,
            'receiver_id' => $admin->id,
            'room_id' => $room->id,
            'text' => 'hello admin',
        ]);

        $json = app(AdminChatService::class)->listChatPartners($admin)->toArray();

        $this->assertCount(1, $json);
        $this->assertSame('hello admin', $json[0]['last_chat']['short_text']);
        $this->assertArrayHasKey('humanize_date', $json[0]['last_chat']);
    }

    #[Test]
    public function partners_are_ordered_newest_conversation_first(): void
    {
        $admin = User::factory()->create();
        [$older, $newer] = User::factory()->count(2)->create();
        foreach ([[$older, now()->subDay()], [$newer, now()]] as [$user, $at]) {
            $room = Room::factory()->between($admin, $user)->create();
            Chat::factory()->create([
                'sender_id' => $user->id, 'receiver_id' => $admin->id,
                'room_id' => $room->id, 'created_at' => $at,
            ]);
        }

        $ids = app(AdminChatService::class)->listChatPartners($admin)->pluck('id')->all();

        $this->assertSame([$newer->id, $older->id], $ids);
    }
}
