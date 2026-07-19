<?php

namespace App\Console\Commands;

use App\Models\Chat;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\GroupMessageUserStatus;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

/**
 * Sweep view-once media whose viewing is finished, so no private-disk bytes
 * linger. The force-quit / never-opened backstop behind the client's
 * consume-on-close fast path (docs/PLAN-view-once-media-2026-07-18.md §12).
 *
 * Deletes the private file (and nulls the pointer) for a one-time message when
 * its fetch window has closed, or 48h after it was sent regardless — the TTL
 * that catches recipients who never open it. Runs hourly; safe to run anytime,
 * on any environment (unlike the staging-only prune, this is a privacy
 * guarantee that must run in production too).
 */
class PruneViewOnceMedia extends Command
{
    protected $signature = 'chat:prune-view-once';

    protected $description = 'Delete view-once media whose window has closed or is 48h old, on all environments.';

    /** Hard TTL: view-once media is gone this long after sending, no matter what. */
    private const TTL_HOURS = 48;

    public function handle(): int
    {
        $ttlCutoff = now()->subHours(self::TTL_HOURS);
        $files = 0;

        // 1:1 — window closed (consume_deadline past) or 48h since send.
        Chat::where('one_time', true)
            ->whereNotNull('file')
            ->where(function ($q) use ($ttlCutoff) {
                $q->where('consume_deadline', '<=', now())
                    ->orWhere('created_at', '<=', $ttlCutoff);
            })
            ->chunkById(200, function ($chats) use (&$files) {
                foreach ($chats as $chat) {
                    $files += $this->deleteFile($chat->file);
                    $chat->update(['file' => null]);
                }
            });

        // Group — 48h since send, or every recipient's window has closed.
        GroupMessage::where('one_time', true)
            ->whereNotNull('file')
            ->chunkById(200, function ($messages) use (&$files, $ttlCutoff) {
                foreach ($messages as $message) {
                    if ($message->created_at > $ttlCutoff
                        && ! $this->allRecipientWindowsClosed($message)) {
                        continue;
                    }
                    $files += $this->deleteFile($message->file);
                    $message->update(['file' => null]);
                }
            });

        $this->info("Pruned {$files} view-once media file(s).");

        return self::SUCCESS;
    }

    /** Whether every non-sender member of [$message]'s group has a closed window. */
    private function allRecipientWindowsClosed(GroupMessage $message): bool
    {
        $recipients = GroupMember::where('group_id', $message->group_id)
            ->where('user_id', '!=', $message->sender_id)
            ->count();
        if ($recipients === 0) {
            return true;
        }
        $closed = GroupMessageUserStatus::where('message_id', $message->id)
            ->whereNotNull('consume_deadline')
            ->where('consume_deadline', '<=', now())
            ->count();

        return $closed >= $recipients;
    }

    /** Delete a private-disk file; returns 1 if it was removed, 0 otherwise. */
    private function deleteFile(?string $path): int
    {
        if (! $path || ! Storage::disk('local')->exists($path)) {
            return 0;
        }
        Storage::disk('local')->delete($path);

        return 1;
    }
}
