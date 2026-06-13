<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds the silent-recording consent timestamp to `users` (DG1).
 *
 * Records when a user consented to the patented silent reaction-recording.
 * Nullable: null means "not consented" (the reaction feature stays off for
 * them). This is purely additive — it does not alter any existing column or
 * response shape — so it is safe to deploy ahead of the app and harmless to
 * the OLD live App Store app.
 */
return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('recording_consent_at')->nullable()->after('last_activity_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('recording_consent_at');
        });
    }
};
