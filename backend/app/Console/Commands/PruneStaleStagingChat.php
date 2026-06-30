<?php

namespace App\Console\Commands;

use App\Models\Chat;
use App\Models\GroupMessage;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;

/**
 * STAGING-ONLY: hard-delete chat data (1:1 messages, group messages, reaction
 * messages) and their media files older than the configured age, so the staging
 * environment doesn't keep test content forever.
 *
 * This command is destructive, so it is guarded by TWO independent gates and
 * **no-ops unless both pass** — see config/staging.php:
 *   1. config('staging.prune_enabled') — the staging-only opt-in switch.
 *   2. the app's host must equal config('staging.prune_host') — a positive
 *      allowlist; production (reacti.io) fails this and the command aborts.
 * It is never invoked on production (the scheduled trigger only reaches the
 * staging server), but these gates make it safe even if it were.
 */
class PruneStaleStagingChat extends Command
{
    /** @var string */
    protected $signature = 'chat:prune-stale-staging';

    /** @var string */
    protected $description = 'STAGING ONLY: hard-delete chat/group messages, reactions and media older than the configured age. No-ops anywhere that is not staging.';

    /**
     * Run the prune, after confirming both staging gates pass.
     *
     * @return int Command::SUCCESS on a successful run or a safe no-op;
     *             Command::FAILURE only when the identity gate rejects the host.
     */
    public function handle(): int
    {
        // Gate 1 — explicit opt-in. Only the staging .env sets this true.
        if (! config('staging.prune_enabled')) {
            $this->info('staging.prune_enabled is off — nothing pruned.');

            return self::SUCCESS;
        }

        // Gate 2 — positive identity allowlist. Abort unless we are literally the
        // staging host. Production (reacti.io) does not match and never deletes.
        $host = parse_url((string) config('app.url'), PHP_URL_HOST);
        $expected = config('staging.prune_host');
        if ($host !== $expected) {
            $this->error("Refusing to prune: host '{$host}' is not the staging host '{$expected}'.");

            return self::FAILURE;
        }

        $hours = max(1, (int) config('staging.prune_hours'));
        $cutoff = Carbon::now()->subHours($hours);
        $this->info("Pruning chat data created before {$cutoff} ({$hours}h ago)...");

        $files = 0;
        $chats = 0;
        $groupMessages = 0;

        // --- 1:1 chats (includes reaction- and reply-type messages) ---
        // withTrashed(): also clear already soft-deleted rows; forceDelete():
        // actually remove the row (a plain delete would only soft-delete).
        Chat::withTrashed()
            ->where('created_at', '<', $cutoff)
            ->chunkById(500, function ($rows) use (&$files, &$chats) {
                foreach ($rows as $chat) {
                    $files += $this->deleteMedia([$chat->file, $chat->thumbnail]);
                    $chat->forceDelete();
                    $chats++;
                }
            });

        // --- group messages + their per-user status / read rows ---
        // The FKs cascade on hard delete, but we clear children explicitly first
        // so the result doesn't depend on the DB engine enforcing FK cascade.
        GroupMessage::withTrashed()
            ->where('created_at', '<', $cutoff)
            ->chunkById(500, function ($rows) use (&$files, &$groupMessages) {
                $ids = $rows->pluck('id')->all();
                DB::table('group_message_user_statuses')->whereIn('message_id', $ids)->delete();
                DB::table('group_message_reads')->whereIn('group_message_id', $ids)->delete();
                foreach ($rows as $message) {
                    $files += $this->deleteMedia([$message->file]);
                    $message->forceDelete();
                    $groupMessages++;
                }
            });

        $this->info("Pruned {$chats} chats, {$groupMessages} group messages, {$files} media files.");

        return self::SUCCESS;
    }

    /**
     * Delete the given stored media paths from public storage.
     *
     * @param  array<int, string|null>  $paths  Relative paths as stored in the
     *                                          `file`/`thumbnail` columns (e.g.
     *                                          `uploads/chat/x.jpg`); null/empty
     *                                          entries are skipped.
     * @return int How many files were actually removed.
     */
    private function deleteMedia(array $paths): int
    {
        $removed = 0;
        foreach ($paths as $path) {
            if (! $path) {
                continue;
            }
            $full = public_path($path);
            if (File::exists($full)) {
                File::delete($full);
                $removed++;
            }
        }

        return $removed;
    }
}
