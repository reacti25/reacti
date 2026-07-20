<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add `read_at` to `chats` — the exact time a 1:1 message was first seen.
 *
 * Stamped once (first read wins) when the recipient opens the conversation, or
 * on `mark-viewed` for media. Null until read. Powers the exact "Seen" time in
 * the message details sheet; the coarse `status` enum is unchanged.
 *
 * `delivered_at` is deliberately omitted: nothing in the app sets a
 * `delivered` status, so a delivered timestamp would never populate.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->timestamp('read_at')->nullable()->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->dropColumn('read_at');
        });
    }
};
