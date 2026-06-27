<?php

namespace Tests\Feature\Staging;

use App\Models\Chat;
use App\Models\GroupMessage;
use App\Models\GroupMessageUserStatus;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use Tests\TestCase;

/**
 * Tests for the staging-only `chat:prune-stale-staging` command.
 *
 * The safety-critical cases come first: the command must delete NOTHING unless
 * both gates pass (the opt-in switch AND the staging-host identity check), so
 * production — where neither holds — can never lose data.
 */
class PruneStaleStagingChatTest extends TestCase
{
    use RefreshDatabase;

    /** Put the command in its "allowed to run" state (both gates pass). */
    private function enableStagingGates(): void
    {
        config([
            'staging.prune_enabled' => true,
            'staging.prune_host' => 'staging.reacti.io',
            'staging.prune_hours' => 24,
            'app.url' => 'https://staging.reacti.io',
        ]);
    }

    public function test_it_does_nothing_when_the_opt_in_switch_is_off(): void
    {
        // Gate 1 off — even though the host would be fine and the data is old.
        config([
            'staging.prune_enabled' => false,
            'app.url' => 'https://staging.reacti.io',
        ]);
        $chat = Chat::factory()->create(['created_at' => now()->subHours(48)]);

        $this->artisan('chat:prune-stale-staging')->assertSuccessful();

        $this->assertDatabaseHas('chats', ['id' => $chat->id]);
    }

    public function test_it_refuses_and_deletes_nothing_when_host_is_not_staging(): void
    {
        // Gate 1 on, but Gate 2 fails — this is the production-shaped case.
        config([
            'staging.prune_enabled' => true,
            'staging.prune_host' => 'staging.reacti.io',
            'app.url' => 'https://reacti.io', // production host
        ]);
        $chat = Chat::factory()->create(['created_at' => now()->subHours(48)]);

        $this->artisan('chat:prune-stale-staging')->assertFailed();

        $this->assertDatabaseHas('chats', ['id' => $chat->id]);
    }

    public function test_it_prunes_old_chats_and_group_messages_but_keeps_recent_ones(): void
    {
        $this->enableStagingGates();

        $oldChat = Chat::factory()->create(['created_at' => now()->subHours(25)]);
        $recentChat = Chat::factory()->create(['created_at' => now()->subHours(2)]);
        $oldReaction = Chat::factory()->create([
            'message_type' => 'reaction',
            'created_at' => now()->subHours(30),
        ]);

        $oldGroup = GroupMessage::factory()->create(['created_at' => now()->subHours(25)]);
        $recentGroup = GroupMessage::factory()->create(['created_at' => now()->subHours(1)]);

        // A per-user status row hanging off the old group message must go too.
        GroupMessageUserStatus::create([
            'message_id' => $oldGroup->id,
            'user_id' => User::factory()->create()->id,
            'is_viewed' => true,
            'is_blurred' => false,
        ]);

        $this->artisan('chat:prune-stale-staging')->assertSuccessful();

        // Old content (incl. reactions) is gone — hard-deleted, not soft.
        $this->assertDatabaseMissing('chats', ['id' => $oldChat->id]);
        $this->assertDatabaseMissing('chats', ['id' => $oldReaction->id]);
        $this->assertDatabaseMissing('group_messages', ['id' => $oldGroup->id]);
        $this->assertDatabaseMissing('group_message_user_statuses', ['message_id' => $oldGroup->id]);

        // Recent content survives.
        $this->assertDatabaseHas('chats', ['id' => $recentChat->id]);
        $this->assertDatabaseHas('group_messages', ['id' => $recentGroup->id]);
    }

    public function test_it_deletes_the_media_file_of_a_pruned_message(): void
    {
        $this->enableStagingGates();

        $relativePath = 'uploads/prune-test/old-media.jpg';
        File::ensureDirectoryExists(public_path('uploads/prune-test'));
        File::put(public_path($relativePath), 'fake-bytes');

        Chat::factory()->create([
            'file' => $relativePath,
            'file_type' => 'image',
            'created_at' => now()->subHours(25),
        ]);

        $this->artisan('chat:prune-stale-staging')->assertSuccessful();

        $this->assertFileDoesNotExist(public_path($relativePath));
    }

    protected function tearDown(): void
    {
        // Clean up the media-test directory if a test left it behind.
        $dir = public_path('uploads/prune-test');
        if (File::isDirectory($dir)) {
            File::deleteDirectory($dir);
        }
        parent::tearDown();
    }
}
