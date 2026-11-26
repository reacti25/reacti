<?php

use App\Services\OneTimeMediaService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Remember when a one-time exchange was erased.
 *
 * The erase removes the reaction and both files, but keeps the media's row,
 * emptied, so both chats can show a quiet line where it was ("One-time photo
 * · reacted"). Null means the media is still there. See
 * {@see OneTimeMediaService::erase()}.
 *
 * Added only if missing, like the one-time columns before it: a migration
 * that half ran on a server must be able to run again.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('chats', 'one_time_erased_at')) {
            return;
        }
        Schema::table('chats', function (Blueprint $table) {
            $table->timestamp('one_time_erased_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->dropColumn('one_time_erased_at');
        });
    }
};
