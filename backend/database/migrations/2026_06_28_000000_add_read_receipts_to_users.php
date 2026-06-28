<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds a per-user "read receipts" preference (default on).
 *
 * Reciprocal, WhatsApp-style: when false the server withholds the
 * MessageReadEvent "seen" broadcast for messages this user reads, and the
 * client also suppresses rendering "seen". Default true preserves today's
 * behaviour for existing rows.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('read_receipts')->default(true)->after('analytics_opt_out');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('read_receipts');
        });
    }
};
