<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Personal invite codes (Feature 5). Each row is one opaque, reusable code
 * bound to an inviter, shared via the iOS share sheet in reacti.app/i/{code}.
 * A new user arriving with it is offered a one-tap "Connect with {Inviter}".
 * The code is the single source of truth, so a deferred-deep-link provider can
 * be dropped in later with zero schema change (DECISION D4).
 *
 * Reusable (one code per inviter) rather than single-use: a share-sheet link is
 * broadcast to many people, so consumption is recorded by the friendships that
 * result, not by burning the code.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('invites', function (Blueprint $table) {
            $table->id();
            // Opaque, URL-safe code carried in reacti.app/i/{code}. Never PII.
            $table->string('code')->unique();
            // One reusable code per inviter.
            $table->foreignId('inviter_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('invites');
    }
};
