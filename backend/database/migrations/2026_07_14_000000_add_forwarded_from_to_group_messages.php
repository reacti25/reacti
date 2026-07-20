<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add `forwarded_from` to `group_messages`, mirroring the `chats` column.
 *
 * Records the original sender when a message is forwarded into a group, so the
 * client can show a "Forwarded" label. Null means the message was composed
 * normally. On the user's deletion the reference is nulled, not cascaded.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('group_messages', function (Blueprint $table) {
            $table->foreignId('forwarded_from')
                ->nullable()
                ->after('sender_id')
                ->constrained('users')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('group_messages', function (Blueprint $table) {
            $table->dropConstrainedForeignId('forwarded_from');
        });
    }
};
