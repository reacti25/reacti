<?php

namespace App\Console\Commands;

use App\Helpers\Helper;
use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMessage;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

/**
 * One-time cleanup of media files left on the server by deletions that ran
 * before deletes removed files too (see Helper::deleteFiles()).
 *
 * Until then, deleting a message, conversation, group or account removed only
 * database rows, so their photos, videos and reaction videos stayed in
 * public/uploads, still reachable by URL. This finds every file in the chat
 * media folders that no live (not deleted) message or group points at.
 *
 * Safe by default: without --force it only reports what it would delete.
 * Skips files younger than --min-age minutes so an upload whose message row
 * is still being written is never caught. Only the chat-media folders are
 * scanned, never profile pictures or settings images.
 *
 * Usage:
 *   php artisan media:prune-orphans            # report only
 *   php artisan media:prune-orphans --force    # delete
 */
class PruneOrphanMedia extends Command
{
    protected $signature = 'media:prune-orphans
        {--force : Actually delete; without it the command only reports}
        {--min-age=60 : Ignore files modified fewer than this many minutes ago}
        {--folder=* : Scan these folders under public/ instead of the chat-media ones (tests use their own)}';

    protected $description = 'Report (or with --force delete) chat media files that no live message or group references.';

    /** Folders under public/ that hold message media and group avatars. */
    private const FOLDERS = [
        'uploads/chat',
        'uploads/group_message',
        'uploads/group_chat',
        'uploads/groups',
    ];

    public function handle(): int
    {
        $referenced = $this->referencedPaths();
        $cutoff = now()->subMinutes((int) $this->option('min-age'))->getTimestamp();

        $folders = $this->option('folder') ?: self::FOLDERS;

        $orphans = collect($folders)
            ->filter(fn ($folder) => File::isDirectory(public_path($folder)))
            ->flatMap(fn ($folder) => File::allFiles(public_path($folder)))
            ->filter(fn ($file) => $file->getMTime() < $cutoff)
            ->map(fn ($file) => [
                'path' => 'uploads/'.str_replace('\\', '/', substr($file->getPathname(), strlen(public_path('uploads')) + 1)),
                'bytes' => $file->getSize(),
            ])
            ->reject(fn ($file) => isset($referenced[$file['path']]))
            ->values();

        $megabytes = round($orphans->sum('bytes') / 1048576, 1);
        $this->info("{$orphans->count()} orphaned media files ({$megabytes} MB) in ".implode(', ', $folders).'.');
        $orphans->take(10)->each(fn ($file) => $this->line('  '.$file['path']));

        if (! $this->option('force')) {
            $this->warn('Report only. Run again with --force to delete them.');

            return self::SUCCESS;
        }

        $removed = Helper::deleteFiles($orphans->pluck('path'));
        $this->info("Deleted {$removed} files.");

        return self::SUCCESS;
    }

    /**
     * Paths still in use: files of messages and groups that are NOT deleted.
     * Soft-deleted rows are deliberately excluded: nothing in the app shows
     * them, so their files are exactly what this command exists to remove.
     *
     * @return array<string, true> Normalized `uploads/...` paths as keys.
     */
    private function referencedPaths(): array
    {
        $paths = [];
        $add = function ($value) use (&$paths) {
            $relative = Helper::uploadsPath($value);
            if ($relative !== null) {
                $paths[$relative] = true;
            }
        };

        // Whole rows, not select(['id', 'file', 'thumbnail']): production's
        // chats table has no thumbnail column (reading it then gives null).
        Chat::query()->chunkById(1000, function ($chats) use ($add) {
            foreach ($chats as $chat) {
                $add($chat->file);
                $add($chat->thumbnail);
            }
        });
        GroupMessage::select(['id', 'file'])->chunkById(1000, function ($messages) use ($add) {
            foreach ($messages as $message) {
                $add($message->file);
            }
        });
        Group::select(['id', 'avatar'])->get()->each(fn ($group) => $add($group->getRawOriginal('avatar')));

        return $paths;
    }
}
