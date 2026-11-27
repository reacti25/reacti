<?php

use App\Http\Controllers\Api\AppVersionController;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The newest app version per platform, typed in the admin settings once a
 * release is live in its store. Apps older than it offer to update (see
 * {@see AppVersionController}). Null: no update prompt.
 *
 * Added only if missing, so a half-run migration can run again.
 */
return new class extends Migration
{
    private const COLUMNS = ['latest_ios_version', 'latest_android_version'];

    public function up(): void
    {
        $missing = array_filter(self::COLUMNS, fn ($column) => ! Schema::hasColumn('settings', $column));
        if ($missing === []) {
            return;
        }
        Schema::table('settings', function (Blueprint $table) use ($missing) {
            foreach ($missing as $column) {
                $table->string($column, 20)->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('settings', function (Blueprint $table) {
            $table->dropColumn(self::COLUMNS);
        });
    }
};
