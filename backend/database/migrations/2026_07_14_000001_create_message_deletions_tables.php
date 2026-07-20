<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Per-user "delete for me" records for 1:1 and group messages.
 *
 * A row means the given user has hidden that message for themselves only; the
 * message stays intact for everyone else. Because the state lives server-side
 * (not on the device), a hidden message stays hidden when the user signs in on
 * another device. Fetches exclude the caller's rows here.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('chat_message_deletions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('chat_id')->constrained('chats')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamps();
            // One "delete for me" per user per message.
            $table->unique(['chat_id', 'user_id']);
        });

        Schema::create('group_message_deletions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('message_id')->constrained('group_messages')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['message_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chat_message_deletions');
        Schema::dropIfExists('group_message_deletions');
    }
};
