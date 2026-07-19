<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add `consume_deadline` to `chats` — the view-once fetch window.
 *
 * Set when the receiver claims a one-time message (mark-viewed): the media is
 * fetchable only until this instant, after which the streaming endpoint 404s
 * and a janitor deletes the file. Null for every ordinary message and for a
 * one-time message not yet opened.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->timestamp('consume_deadline')->nullable()->after('one_time');
        });
    }

    public function down(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->dropColumn('consume_deadline');
        });
    }
};
