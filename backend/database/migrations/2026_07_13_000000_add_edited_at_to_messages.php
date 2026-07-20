<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add an `edited_at` timestamp to `chats` and `group_messages`.
 *
 * Stamped when a sender edits their own message within the allowed window.
 * A null value means "never edited"; the API derives the `is_edited` flag
 * from it, so no separate boolean column is needed.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->timestamp('edited_at')->nullable()->after('status');
        });

        Schema::table('group_messages', function (Blueprint $table) {
            $table->timestamp('edited_at')->nullable()->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->dropColumn('edited_at');
        });

        Schema::table('group_messages', function (Blueprint $table) {
            $table->dropColumn('edited_at');
        });
    }
};
