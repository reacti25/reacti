<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Drop the unused `deleted_at` column from `users` (DG9 — hard-delete policy).
 *
 * The model never used the SoftDeletes trait — accounts are hard-deleted — so
 * the column the create migration added was dead weight (always null). The
 * `whereNull('deleted_at')` filters that referenced it were removed in the same
 * change. Guarded with `hasColumn` so a fresh install (whose create migration
 * no longer adds the column) is a no-op.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('users', 'deleted_at')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('deleted_at');
            });
        }
    }

    public function down(): void
    {
        if (! Schema::hasColumn('users', 'deleted_at')) {
            Schema::table('users', function (Blueprint $table) {
                $table->softDeletes();
            });
        }
    }
};
