<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

/**
 * Drop the `c_m_s` and `job_categories` tables — leftovers from a
 * different project. Neither table is referenced by any model, service,
 * controller, route, or test in this codebase (verified during the big
 * refactor R2b dead-code sweep). The two create-table migrations
 * (2025_07_19_032913 and 2025_07_19_034506) are deleted in the same
 * commit; this migration cleans up databases where those migrations
 * already ran.
 *
 * `dropIfExists` makes this safe on databases that never had the
 * tables (e.g. fresh CI).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('c_m_s');
        Schema::dropIfExists('job_categories');
    }

    /**
     * No down(). The dropped tables are dead schema from another
     * project; reintroducing them on rollback would just restore the
     * dead code.
     */
    public function down(): void
    {
        //
    }
};
