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
 * View-once group reactions (P3-group): "all members, one-time each".
 *
 * A reaction to a one-time group message is itself one-time — stored privately
 * and sealed per-recipient, so each member opens it once in the protected
 * viewer. A reaction to ordinary group media is unchanged (the patent group
 * reaction path is preserved).
 */
class ViewOnceGroupReactionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        Storage::fake('local');
    }

    /** admin + member; a one-time (or ordinary) media message sent by admin. */
    private function groupWithMedia(bool $oneTime): array
    {
        $admin = User::factory()->create();
        $member = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create(['group_id' => $group->id, 'user_id' => $admin->id]);
        GroupMember::factory()->create(['group_id' => $group->id, 'user_id' => $member->id]);

        $media = GroupMessage::create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'one_time' => $oneTime,
            'file' => 'x/media.jpg',
        ]);

        return [$admin, $member, $group, $media];
    }

    /** A reaction to a one-time group message is private, one-time, sealed. */
    #[Test]
    public function a_group_reaction_to_one_time_media_is_itself_one_time(): void
    {
        [$admin, $member, $group, $media] = $this->groupWithMedia(true);

        // The member uploads their reaction to the one-time media.
        $this->actingAs($member, 'api')->post(
            "/api/auth/group/{$group->id}/send",
            [
                'message_type' => 'reaction',
                'reply_to_message_id' => $media->id,
                'file' => UploadedFile::fake()->create('reaction.mp4', 10, 'video/mp4'),
            ],
            ['Accept' => 'application/json'],
        )->assertOk();

        $reaction = GroupMessage::where('message_type', 'reaction')->first();
        $this->assertTrue((bool) $reaction->one_time);
        $this->assertStringStartsWith('viewonce/group_message/', $reaction->getRawOriginal('file'));

        // The other member's status row for the reaction is sealed.
        $adminStatus = GroupMessageUserStatus::where('message_id', $reaction->id)
            ->where('user_id', $admin->id)->first();
        $this->assertTrue((bool) $adminStatus->is_blurred);
    }

    /** A reaction to ORDINARY group media is unchanged — not one-time, public. */
    #[Test]
    public function a_group_reaction_to_ordinary_media_is_not_one_time(): void
    {
        [$admin, $member, $group, $media] = $this->groupWithMedia(false);

        $this->actingAs($member, 'api')->post(
            "/api/auth/group/{$group->id}/send",
            [
                'message_type' => 'reaction',
                'reply_to_message_id' => $media->id,
                'file' => UploadedFile::fake()->create('reaction.mp4', 10, 'video/mp4'),
            ],
            ['Accept' => 'application/json'],
        )->assertOk();

        $reaction = GroupMessage::where('message_type', 'reaction')->first();
        $this->assertFalse((bool) $reaction->one_time);

        $adminStatus = GroupMessageUserStatus::where('message_id', $reaction->id)
            ->where('user_id', $admin->id)->first();
        $this->assertFalse((bool) $adminStatus->is_blurred);
    }
}
