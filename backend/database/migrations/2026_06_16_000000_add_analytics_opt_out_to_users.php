<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds a per-user analytics opt-out flag.
 *
 * When true, the backend emits NO analytics events that carry this user's id —
 * the durable, cross-device honouring of the app's "Usage Data" opt-out toggle.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('analytics_opt_out')->default(false)->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('analytics_opt_out');
        });
    }
};
