<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds a nullable `thumb_hash` column to both message tables.
 *
 * Holds the ~20-byte base64 ThumbHash of an image message, computed at upload
 * (see ThumbHashService). The client renders it as an instant blurred
 * placeholder while the full image downloads. Nullable: text messages, videos,
 * and pre-existing rows simply have no hash.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->string('thumb_hash')->nullable()->after('file');
        });

        Schema::table('group_messages', function (Blueprint $table) {
            $table->string('thumb_hash')->nullable()->after('file');
        });
    }

    public function down(): void
    {
        Schema::table('chats', function (Blueprint $table) {
            $table->dropColumn('thumb_hash');
        });

        Schema::table('group_messages', function (Blueprint $table) {
            $table->dropColumn('thumb_hash');
        });
    }
};
