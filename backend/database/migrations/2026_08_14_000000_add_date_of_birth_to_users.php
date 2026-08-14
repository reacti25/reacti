<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds the birthdate captured by the signup age gate.
 *
 * Nullable on purpose: every account that existed before the gate has no
 * birthdate on file, and back-filling one we don't have would be inventing
 * data. Those accounts are handled by the one-time age confirmation at launch
 * (see docs/PLAN-age-gate-2026-08-04.md); a null here means "never asked",
 * which is exactly what that screen looks for.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->date('date_of_birth')->nullable()->after('phone');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('date_of_birth');
        });
    }
};
