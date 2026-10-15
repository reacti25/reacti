<?php

namespace Tests\Feature\Privacy;

use App\Helpers\Helper;
use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\Room;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Schema;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;
use Tymon\JWTAuth\Facades\JWTAuth;

/**
 * Deleting a message, a conversation, a group or an account must remove the
 * photo/video/reaction FILES from the server, not only the database rows.
 *
 * Before this, every one of these paths left the files on disk, reachable by
 * URL, contradicting the privacy policy and Google Play's account-deletion
 * requirement. Each test puts a real file under public/uploads/, runs the
 * real endpoint, and checks the file is gone (or, for "delete for me", kept).
 */
class MediaDeletionTest extends TestCase
{
    use RefreshDatabase;

    private const DIR = 'uploads/media-deletion-test';

    protected function tearDown(): void
    {
        File::deleteDirectory(public_path(self::DIR));
        parent::tearDown();
    }

    /** A real file under public/uploads, returned as its stored path. */
    private function mediaFile(string $name): string
    {
        File::ensureDirectoryExists(public_path(self::DIR));
        File::put(public_path(self::DIR.'/'.$name), 'fake-bytes');

        return self::DIR.'/'.$name;
    }

    /** A 1:1 media message from $from to $to, with its file on disk. */
    private function chatWithMedia(User $from, User $to, string $name): Chat
    {
        $room = Room::where('user_one_id', min($from->id, $to->id))
            ->where('user_two_id', max($from->id, $to->id))->first()
            ?? Room::factory()->between($from, $to)->create();

        return Chat::factory()->create([
            'sender_id' => $from->id,
            'receiver_id' => $to->id,
            'room_id' => $room->id,
            'file' => $this->mediaFile($name),
        ]);
    }

    #[Test]
    public function deleting_a_message_for_everyone_removes_its_file(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $chat = $this->chatWithMedia($a, $b, 'photo.jpg');

        $this->actingAs($a, 'api')
            ->deleteJson('/api/auth/chat/delete/chat/messages', ['message_id' => $chat->id])
            ->assertOk();

        $this->assertFileDoesNotExist(public_path($chat->file));
    }

    #[Test]
    public function deleting_a_message_for_me_keeps_its_file(): void
    {
        // The other person still sees it, so the file must stay.
        [$a, $b] = User::factory()->count(2)->create();
        $chat = $this->chatWithMedia($a, $b, 'kept.jpg');

        $this->actingAs($b, 'api')
            ->postJson('/api/auth/chat/delete-for-me', ['message_id' => $chat->id])
            ->assertOk();

        $this->assertFileExists(public_path($chat->file));
    }

    #[Test]
    public function deleting_a_conversation_removes_all_its_files(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $sent = $this->chatWithMedia($a, $b, 'sent.jpg');
        $received = $this->chatWithMedia($b, $a, 'received.mp4');

        $this->actingAs($a, 'api')
            ->deleteJson("/api/auth/chat/delete/{$b->id}")
            ->assertOk();

        $this->assertFileDoesNotExist(public_path($sent->file));
        $this->assertFileDoesNotExist(public_path($received->file));
    }

    #[Test]
    public function an_admin_deleting_group_messages_removes_their_files(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        GroupMember::factory()->admin()->create(['group_id' => $group->id, 'user_id' => $admin->id]);
        $message = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $admin->id,
            'file' => $this->mediaFile('group.jpg'),
        ]);

        $this->actingAs($admin, 'api')
            ->deleteJson("/api/auth/group/{$group->id}/delete-messages", ['message_ids' => [$message->id]])
            ->assertOk();

        $this->assertFileDoesNotExist(public_path($message->file));
    }

    #[Test]
    public function deleting_a_group_removes_its_messages_files_and_avatar(): void
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $group = Group::factory()->create([
            'created_by' => $owner->id,
            'avatar' => $this->mediaFile('avatar.jpg'),
        ]);
        $fromOther = GroupMessage::factory()->create([
            'group_id' => $group->id,
            'sender_id' => $other->id,
            'file' => $this->mediaFile('from-other.jpg'),
        ]);

        $this->actingAs($owner, 'api')
            ->deleteJson("/api/auth/group/{$group->id}/delete")
            ->assertOk();

        $this->assertFileDoesNotExist(public_path($fromOther->file));
        $this->assertFileDoesNotExist(public_path(self::DIR.'/avatar.jpg'));
    }

    #[Test]
    public function deleting_an_account_removes_every_file_it_leaves_behind(): void
    {
        $leaver = User::factory()->create();
        $friend = User::factory()->create();

        $sent = $this->chatWithMedia($leaver, $friend, 'sent.jpg');
        $received = $this->chatWithMedia($friend, $leaver, 'received.jpg');
        $deletedEarlier = $this->chatWithMedia($leaver, $friend, 'soft-deleted.jpg');
        $deletedEarlier->delete(); // soft-deleted: row hidden, file still on disk

        // A group the leaver created: the database cascade deletes it with
        // everyone's messages, so the friend's file there goes too.
        $ownGroup = Group::factory()->create(['created_by' => $leaver->id]);
        $friendInOwnGroup = GroupMessage::factory()->create([
            'group_id' => $ownGroup->id,
            'sender_id' => $friend->id,
            'file' => $this->mediaFile('friend-in-own-group.jpg'),
        ]);

        // Someone else's group: only the leaver's own message goes.
        $otherGroup = Group::factory()->create(['created_by' => $friend->id]);
        $leaverInOtherGroup = GroupMessage::factory()->create([
            'group_id' => $otherGroup->id,
            'sender_id' => $leaver->id,
            'file' => $this->mediaFile('leaver-in-other-group.jpg'),
        ]);
        $friendInOtherGroup = GroupMessage::factory()->create([
            'group_id' => $otherGroup->id,
            'sender_id' => $friend->id,
            'file' => $this->mediaFile('friend-in-other-group.jpg'),
        ]);

        // A real bearer token, not actingAs(): deleteProfile() ends with a
        // logout that parses the token off the request (see UserProfileTest).
        $this->withHeader('Authorization', 'Bearer '.JWTAuth::fromUser($leaver))
            ->deleteJson('/api/delete-profile')
            ->assertOk();

        foreach ([$sent, $received, $deletedEarlier] as $chat) {
            $this->assertFileDoesNotExist(public_path($chat->file));
        }
        $this->assertFileDoesNotExist(public_path($friendInOwnGroup->file));
        $this->assertFileDoesNotExist(public_path($leaverInOtherGroup->file));
        // The friend's message in the friend's own group is untouched.
        $this->assertFileExists(public_path($friendInOtherGroup->file));
    }

    #[Test]
    public function delete_files_accepts_full_urls_and_refuses_paths_outside_uploads(): void
    {
        $path = $this->mediaFile('from-url.jpg');
        File::put(public_path('media-deletion-outside.txt'), 'must survive');

        $removed = Helper::deleteFiles([
            "https://reacti.io/{$path}?v=2",      // older rows store full URLs
            null,
            '',
            'media-deletion-outside.txt',         // not under uploads/
            'uploads/../media-deletion-outside.txt', // climbing out
        ]);

        $this->assertSame(1, $removed);
        $this->assertFileDoesNotExist(public_path($path));
        $this->assertFileExists(public_path('media-deletion-outside.txt'));
        File::delete(public_path('media-deletion-outside.txt'));
    }

    /** SQL of every query run after dropThumbnailColumn(). */
    private array $queries = [];

    /**
     * Production's chats table has no `thumbnail` column: the database
     * predates that column being added to the create migration. Naming it in
     * a query broke delete-conversation, delete-account and the cleanup
     * command on production (2026-10-15, MySQL "Unknown column 'thumbnail'").
     *
     * SQLite cannot reproduce the error: it reads an unknown double-quoted
     * column as the string "thumbnail". So these tests drop the column, record
     * every query, and fail if any still names it, which MySQL rejects.
     */
    private function dropThumbnailColumn(): void
    {
        Schema::table('chats', fn (Blueprint $table) => $table->dropColumn('thumbnail'));
        DB::listen(function ($query) {
            $this->queries[] = $query->sql;
        });
    }

    private function assertNoQueryNamesThumbnail(): void
    {
        $offending = array_values(array_filter($this->queries, fn ($sql) => str_contains($sql, 'thumbnail')));
        $this->assertSame([], $offending, 'a query names the thumbnail column production does not have');
    }

    #[Test]
    public function deleting_a_conversation_never_names_the_missing_thumbnail_column(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $chat = $this->chatWithMedia($a, $b, 'conversation.jpg');
        $this->dropThumbnailColumn();

        $this->actingAs($a, 'api')->deleteJson("/api/auth/chat/delete/{$b->id}")->assertOk();

        $this->assertNoQueryNamesThumbnail();
        $this->assertFileDoesNotExist(public_path($chat->file));
    }

    #[Test]
    public function deleting_an_account_never_names_the_missing_thumbnail_column(): void
    {
        [$leaver, $friend] = User::factory()->count(2)->create();
        $chat = $this->chatWithMedia($leaver, $friend, 'leaver.jpg');
        $this->dropThumbnailColumn();

        $this->withHeader('Authorization', 'Bearer '.JWTAuth::fromUser($leaver))
            ->deleteJson('/api/delete-profile')
            ->assertOk();

        $this->assertNoQueryNamesThumbnail();
        $this->assertFileDoesNotExist(public_path($chat->file));
    }

    #[Test]
    public function deleting_one_message_never_names_the_missing_thumbnail_column(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $chat = $this->chatWithMedia($a, $b, 'one.jpg');
        $this->dropThumbnailColumn();

        $this->actingAs($a, 'api')
            ->deleteJson('/api/auth/chat/delete/chat/messages', ['message_id' => $chat->id])
            ->assertOk();

        $this->assertNoQueryNamesThumbnail();
        $this->assertFileDoesNotExist(public_path($chat->file));
    }

    #[Test]
    public function the_cleanup_command_never_names_the_missing_thumbnail_column(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $this->chatWithMedia($a, $b, 'kept.jpg');
        $this->dropThumbnailColumn();

        $this->artisan('media:prune-orphans', ['--folder' => [self::DIR]])->assertSuccessful();

        $this->assertNoQueryNamesThumbnail();
    }
}
