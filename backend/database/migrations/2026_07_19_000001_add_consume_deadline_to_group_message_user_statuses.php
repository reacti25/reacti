<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add `consume_deadline` to `group_message_user_statuses` — the per-recipient
 * view-once fetch window.
 *
 * Group blur/view state is per-recipient, so the window is too: each member's
 * mark-viewed opens their own window against the shared file. The physical file
 * is deleted only once every recipient's window has closed (or the 48h TTL).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('group_message_user_statuses', function (Blueprint $table) {
            $table->timestamp('consume_deadline')->nullable()->after('is_viewed');
        });
    }

    public function down(): void
    {
        Schema::table('group_message_user_statuses', function (Blueprint $table) {
            $table->dropColumn('consume_deadline');
        });
    }
};
