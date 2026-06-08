<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Index the users.role and users.status enum columns (backlog §4 / EP5).
 *
 * Both are filtered by user-listing and authorization queries but were
 * unindexed. The other columns flagged in §4 (friends.friend_id,
 * group_messages.reply_to_message_id, group_message_reads.user_id) are foreign
 * keys and are therefore already indexed by their constraints, so indexing
 * them again would be redundant.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->index('role');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['role']);
            $table->dropIndex(['status']);
        });
    }
};
