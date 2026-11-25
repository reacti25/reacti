<?php

use App\Services\OneTimeMediaService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Remember when the person viewing a one-time message took a screenshot.
 *
 * Android blocks screenshots while one-time media is open; an iPhone cannot,
 * so its app reports one instead, and the sender's tile says "Screenshot
 * taken". Null means no screenshot was reported. See
 * {@see OneTimeMediaService::recordScreenshot()}.
 *
 * Added only if missing, like the one-time columns before it: a migration
 * that half ran on a server must be able to run again.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('chats', 'one_time_screenshot_at')) {
            return;
        }
        Schema::table('chats', function (Blueprint $table) {
            $table->timestamp('one_time_screenshot_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->dropColumn('one_time_screenshot_at');
        });
    }
};
