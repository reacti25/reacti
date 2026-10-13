<?php

namespace Tests\Feature\Privacy;

use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The one-time cleanup of media files earlier deletions left on the server
 * (media:prune-orphans). It must delete only files nothing live points at,
 * never touch anything without --force, and never catch a fresh upload.
 *
 * Runs against its own folder via --folder, so it can never touch a
 * developer's real uploads.
 */
class PruneOrphanMediaTest extends TestCase
{
    use RefreshDatabase;

    private const DIR = 'uploads/orphan-media-test';

    protected function tearDown(): void
    {
        File::deleteDirectory(public_path(self::DIR));
        parent::tearDown();
    }

    /** A real file, aged $minutes, returned as its stored path. */
    private function file(string $name, int $minutes = 120): string
    {
        File::ensureDirectoryExists(public_path(self::DIR));
        $full = public_path(self::DIR.'/'.$name);
        File::put($full, 'fake-bytes');
        touch($full, now()->subMinutes($minutes)->getTimestamp());

        return self::DIR.'/'.$name;
    }

    /** Runs the command on the test folder only. */
    private function prune(bool $force)
    {
        return $this->artisan('media:prune-orphans', array_filter([
            '--folder' => [self::DIR],
            '--force' => $force,
        ]));
    }

    /** Builds one of each case and returns their paths by role. */
    private function scenario(): array
    {
        [$a, $b] = User::factory()->count(2)->create();
        $room = Room::factory()->between($a, $b)->create();
        $chat = fn (string $file) => Chat::factory()->create([
            'sender_id' => $a->id, 'receiver_id' => $b->id, 'room_id' => $room->id, 'file' => $file,
        ]);

        $live = $this->file('live.jpg');
        $chat($live);

        $softDeleted = $this->file('deleted-message.jpg');
        $chat($softDeleted)->delete();

        $group = Group::factory()->create(['avatar' => $this->file('group-avatar.jpg')]);
        $liveGroupMedia = $this->file('group-live.jpg');
        GroupMessage::factory()->create(['group_id' => $group->id, 'sender_id' => $a->id, 'file' => $liveGroupMedia]);

        return [
            'live' => $live,
            'liveGroupMedia' => $liveGroupMedia,
            'groupAvatar' => self::DIR.'/group-avatar.jpg',
            'softDeleted' => $softDeleted,
            'unreferenced' => $this->file('left-behind.mp4'),
            'freshUpload' => $this->file('just-uploaded.jpg', minutes: 5),
        ];
    }

    #[Test]
    public function without_force_it_only_reports(): void
    {
        $files = $this->scenario();

        $this->prune(force: false)
            ->expectsOutputToContain('2 orphaned media files')
            ->expectsOutputToContain('Report only')
            ->assertSuccessful();

        foreach ($files as $path) {
            $this->assertFileExists(public_path($path));
        }
    }

    #[Test]
    public function with_force_it_deletes_only_unreferenced_old_files(): void
    {
        $files = $this->scenario();

        $this->prune(force: true)->expectsOutputToContain('Deleted 2 files')->assertSuccessful();

        // Gone: nothing live points at them.
        $this->assertFileDoesNotExist(public_path($files['unreferenced']));
        $this->assertFileDoesNotExist(public_path($files['softDeleted']));
        // Kept: still in use, or too new to judge.
        $this->assertFileExists(public_path($files['live']));
        $this->assertFileExists(public_path($files['liveGroupMedia']));
        $this->assertFileExists(public_path($files['groupAvatar']));
        $this->assertFileExists(public_path($files['freshUpload']));
    }

    #[Test]
    public function full_url_references_still_count_as_in_use(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $room = Room::factory()->between($a, $b)->create();
        $path = $this->file('stored-as-url.jpg');
        Chat::factory()->create([
            'sender_id' => $a->id, 'receiver_id' => $b->id, 'room_id' => $room->id,
            'file' => "https://reacti.io/{$path}",
        ]);

        $this->prune(force: true)->assertSuccessful();

        $this->assertFileExists(public_path($path));
    }
}
