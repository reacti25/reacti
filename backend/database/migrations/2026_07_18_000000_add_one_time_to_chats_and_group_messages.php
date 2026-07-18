<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add `one_time` to `chats` and `group_messages` — the view-once flag.
 *
 * When true, the media is a "view-once" send: it opens full-screen for the
 * recipient, records the usual reaction, and is then destroyed. Default false,
 * so every existing and ordinary message is unaffected. This migration is the
 * dark foundation (P1); nothing reads the flag to destroy media yet.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->boolean('one_time')->default(false)->after('is_viewed');
        });

        Schema::table('group_messages', function (Blueprint $table) {
            // group_messages has no is_viewed column (per-recipient view state
            // lives in group_message_user_statuses), so anchor after message_type.
            $table->boolean('one_time')->default(false)->after('message_type');
        });
    }

    public function down(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->dropColumn('one_time');
        });

        Schema::table('group_messages', function (Blueprint $table) {
            $table->dropColumn('one_time');
        });
    }
};
