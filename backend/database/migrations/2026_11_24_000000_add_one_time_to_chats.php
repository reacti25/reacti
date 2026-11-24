<?php

use App\Services\OneTimeMediaService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add one-time ("view once") media to 1:1 chats.
 *
 * `one_time` marks a photo or video the sender sent as a one-timer, and the
 * reaction recorded while it was watched (the reaction inherits the flag).
 * `one_time_opened_at` is the moment its recipient opened it: for the media,
 * when it was unsealed; for the reaction, when the original sender pressed
 * play. That stamp starts the short window after which the server stops
 * serving the file. See {@see OneTimeMediaService}.
 *
 * Each piece is added only if it is missing. The July 2026 attempt at this
 * feature (parked on `feature/view-once-media-parked`) added a bare
 * `chats.one_time` column on every server its migration ran on, and the
 * revert of that code left the column behind: staging refused this migration
 * with "Duplicate column name 'one_time'" on 2026-11-24. The leftover column
 * has the same type and default, so it is reused as it is.
 *
 * No `after()`: production's chats table does not have every column staging
 * has, and a missing anchor column fails the migration on MySQL.
 */
return new class extends Migration
{
    public function up(): void
    {
        $hasFlag = Schema::hasColumn('chats', 'one_time');
        $hasFlagIndex = $hasFlag && Schema::hasIndex('chats', ['one_time']);
        $hasOpenedAt = Schema::hasColumn('chats', 'one_time_opened_at');

        Schema::table('chats', function (Blueprint $table) use ($hasFlag, $hasFlagIndex, $hasOpenedAt) {
            if (! $hasFlag) {
                $table->boolean('one_time')->default(false);
            }
            if (! $hasFlagIndex) {
                $table->index('one_time');
            }
            if (! $hasOpenedAt) {
                $table->timestamp('one_time_opened_at')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->dropIndex(['one_time']);
            $table->dropColumn(['one_time', 'one_time_opened_at']);
        });
    }
};
