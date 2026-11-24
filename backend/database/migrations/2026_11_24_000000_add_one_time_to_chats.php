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
 * No `after()`: production's chats table does not have every column staging
 * has, and a missing anchor column fails the migration on MySQL.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->boolean('one_time')->default(false)->index();
            $table->timestamp('one_time_opened_at')->nullable();
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
