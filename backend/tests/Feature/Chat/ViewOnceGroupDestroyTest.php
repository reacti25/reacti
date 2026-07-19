<?php

namespace Tests\Feature\Chat;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\GroupMessageUserStatus;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * View-once fetch window + destroy for GROUPS (P2d-group).
 *
 * The window is per-recipient; the shared file is destroyed only once every
 * recipient's window has closed. Pins: mark-viewed opens a member's window,
 * a member can't stream before claiming, and the file survives one member's
 * consume but is deleted once the last member consumes.
 */
class ViewOnceGroupDestroyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        Storage::fake('local');
    }

    /**
     * Admin + two members, with a one-time group media message sent by admin.
     * Returns [admin, memberA, memberB, message].
     */
    private function groupWithOneTimeMedia(): array
    {
        $admin = User::factory()->create();
        $a = User::factory()->create();
        $b = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create(['group_id' => $group->id, 'user_id' => $admin->id]);
        GroupMember::factory()->create(['group_id' => $group->id, 'user_id' => $a->id]);
        GroupMember::factory()->create(['group_id' => $group->id, 'user_id' => $b->id]);

        $this->actingAs($admin, 'api')->post(
            "/api/auth/group/{$group->id}/send",
            ['file' => UploadedFile::fake()->image('secret.jpg'), 'one_time' => 1],
            ['Accept' => 'application/json'],
        )->assertOk();

        return [$admin, $a, $b, GroupMessage::first()];
    }

    /** A member can't stream before opening their window (mark-viewed). */
    #[Test]
    public function member_cannot_stream_before_claiming(): void
    {
        [, $a, , $message] = $this->groupWithOneTimeMedia();

        $this->actingAs($a, 'api')
            ->get("/api/auth/group/one-time-media/{$message->id}")
            ->assertStatus(404);
    }

    /** mark-viewed opens the member's window and stamps a deadline. */
    #[Test]
    public function mark_viewed_opens_the_members_window(): void
    {
        [, $a, , $message] = $this->groupWithOneTimeMedia();

        $this->actingAs($a, 'api')
            ->postJson("/api/auth/group/mark-viewed/{$message->id}")
            ->assertOk();

        $status = GroupMessageUserStatus::where('message_id', $message->id)
            ->where('user_id', $a->id)->first();
        $this->assertNotNull($status->consume_deadline);
    }

    /** The shared file survives until EVERY recipient has consumed. */
    #[Test]
    public function file_survives_one_consume_and_dies_on_the_last(): void
    {
        [, $a, $b, $message] = $this->groupWithOneTimeMedia();
        $stored = $message->getRawOriginal('file');

        // Both members claim (open their windows).
        $this->actingAs($a, 'api')->postJson("/api/auth/group/mark-viewed/{$message->id}")->assertOk();
        $this->actingAs($b, 'api')->postJson("/api/auth/group/mark-viewed/{$message->id}")->assertOk();

        // Member A consumes → file must still exist (B hasn't finished).
        $this->actingAs($a, 'api')->postJson("/api/auth/group/one-time-media/{$message->id}/consume")->assertOk();
        Storage::disk('local')->assertExists($stored);
        $this->assertNotNull($message->fresh()->getRawOriginal('file'));

        // Member B consumes → all windows closed → file destroyed.
        $this->actingAs($b, 'api')->postJson("/api/auth/group/one-time-media/{$message->id}/consume")->assertOk();
        Storage::disk('local')->assertMissing($stored);
        $this->assertNull($message->fresh()->getRawOriginal('file'));
    }

    /** A non-member cannot consume — the file survives their call. */
    #[Test]
    public function a_non_member_cannot_consume(): void
    {
        [, , , $message] = $this->groupWithOneTimeMedia();
        $stored = $message->getRawOriginal('file');
        $outsider = User::factory()->create();

        $this->actingAs($outsider, 'api')
            ->postJson("/api/auth/group/one-time-media/{$message->id}/consume")
            ->assertOk();

        Storage::disk('local')->assertExists($stored);
    }
}
