<?php

namespace Tests\Feature\Chat;

use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\GroupMessageUserStatus;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The view-once janitor (`chat:prune-view-once`) — the force-quit / never-opened
 * backstop that guarantees no private-disk bytes linger.
 */
class PruneViewOnceMediaTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
    }

    private function chatWith(array $attrs): Chat
    {
        $chat = Chat::factory()->create(array_merge([
            'one_time' => true,
            'file' => 'viewonce/chat/x.jpg',
        ], $attrs));
        Storage::disk('local')->put($chat->getRawOriginal('file'), 'bytes');

        return $chat;
    }

    /** A closed window (deadline past) → file swept, pointer nulled. */
    #[Test]
    public function sweeps_media_whose_window_has_closed(): void
    {
        $chat = $this->chatWith(['consume_deadline' => now()->subMinute()]);

        $this->artisan('chat:prune-view-once')->assertSuccessful();

        Storage::disk('local')->assertMissing('viewonce/chat/x.jpg');
        $this->assertNull($chat->fresh()->getRawOriginal('file'));
    }

    /** Never opened (no deadline) but 48h old → swept by the TTL. */
    #[Test]
    public function sweeps_media_older_than_the_ttl_even_if_never_opened(): void
    {
        $chat = $this->chatWith([
            'consume_deadline' => null,
            'created_at' => now()->subHours(49),
        ]);

        $this->artisan('chat:prune-view-once')->assertSuccessful();

        Storage::disk('local')->assertMissing('viewonce/chat/x.jpg');
    }

    /** A fresh, unopened one-time message is left alone. */
    #[Test]
    public function leaves_fresh_unopened_media_alone(): void
    {
        $this->chatWith(['consume_deadline' => null, 'created_at' => now()]);

        $this->artisan('chat:prune-view-once')->assertSuccessful();

        Storage::disk('local')->assertExists('viewonce/chat/x.jpg');
    }

    /** Ordinary (non-one-time) media is never touched. */
    #[Test]
    public function never_touches_ordinary_media(): void
    {
        $this->chatWith([
            'one_time' => false,
            'created_at' => now()->subHours(72),
        ]);

        $this->artisan('chat:prune-view-once')->assertSuccessful();

        Storage::disk('local')->assertExists('viewonce/chat/x.jpg');
    }

    /** Group media is swept once every recipient window has closed. */
    #[Test]
    public function sweeps_group_media_when_all_windows_closed(): void
    {
        $admin = User::factory()->create();
        $a = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create(['group_id' => $group->id, 'user_id' => $admin->id]);
        GroupMember::factory()->create(['group_id' => $group->id, 'user_id' => $a->id]);

        $message = GroupMessage::create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'one_time' => true,
            'file' => 'viewonce/group_message/x.jpg',
        ]);
        Storage::disk('local')->put('viewonce/group_message/x.jpg', 'bytes');
        // The one recipient's window is closed.
        GroupMessageUserStatus::create([
            'message_id' => $message->id,
            'user_id' => $a->id,
            'is_viewed' => true,
            'consume_deadline' => now()->subMinute(),
        ]);

        $this->artisan('chat:prune-view-once')->assertSuccessful();

        Storage::disk('local')->assertMissing('viewonce/group_message/x.jpg');
    }
}
