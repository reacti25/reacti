<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Counters that make the invite loop measurable end to end.
 *
 * Reacti grows by invitation: a personal link, a web demo for people who have
 * not installed, and a Universal Link that connects the two accounts on open.
 * That is a viral loop, and nothing measured whether it worked — the app knew
 * an invite had been shared and, much later, that someone connected, with the
 * whole middle invisible.
 *
 * Counted here rather than sent to a third party on purpose. The landing page
 * is public and anonymous; putting an analytics script on it would mean cookies
 * and a consent banner for people who have not even installed the app. These
 * are counters on a row we already own, they identify nobody, and K-factor
 * becomes a SQL query.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invites', function (Blueprint $table) {
            // Landing page rendered. Counted, not a boolean: a link shared into
            // a group chat is opened many times, and that IS the reach.
            $table->unsignedInteger('opened_count')->default(0)->after('inviter_id');
            // The web demo reached its reveal — the point of the page.
            $table->unsignedInteger('demo_completed_count')->default(0)->after('opened_count');
            // The App Store button was tapped. The last thing measurable before
            // Apple takes over; the install itself is only visible again when
            // the account connects.
            $table->unsignedInteger('store_clicked_count')->default(0)->after('demo_completed_count');
            // First open, for time-to-first-open per invite.
            $table->timestamp('first_opened_at')->nullable()->after('store_clicked_count');
        });
    }

    public function down(): void
    {
        Schema::table('invites', function (Blueprint $table) {
            $table->dropColumn([
                'opened_count',
                'demo_completed_count',
                'store_clicked_count',
                'first_opened_at',
            ]);
        });
    }
};
