<?php

namespace Tests\Feature\Database;

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The group one-time migration must finish on the servers as they are: the
 * July 2026 attempt left `group_messages.one_time` (and a
 * `consume_deadline` on the status rows) behind, and the 1:1 version of this
 * migration broke the first staging deploy on exactly that.
 */
class GroupOneTimeMigrationTest extends TestCase
{
    use RefreshDatabase;

    /** The columns the migration owns, per table. */
    private const COLUMNS = [
        'group_messages' => ['one_time', 'one_time_screenshot_at', 'one_time_erased_at', 'one_time_reacted', 'one_time_recipients'],
        'group_message_user_statuses' => ['opened_at', 'done_at'],
    ];

    #[Test]
    public function it_finishes_on_tables_that_already_have_the_july_columns(): void
    {
        $migration = $this->migration();
        $migration->down();
        Schema::table('group_messages', fn (Blueprint $table) => $table->boolean('one_time')->default(false));
        Schema::table('group_message_user_statuses', fn (Blueprint $table) => $table->timestamp('consume_deadline')->nullable());

        $migration->up();

        $this->assertAllColumnsExist();
    }

    #[Test]
    public function running_it_twice_changes_nothing_and_does_not_fail(): void
    {
        $this->migration()->up();

        $this->assertAllColumnsExist();
    }

    private function assertAllColumnsExist(): void
    {
        foreach (self::COLUMNS as $table => $columns) {
            foreach ($columns as $column) {
                $this->assertTrue(Schema::hasColumn($table, $column), "$table.$column");
            }
        }
    }

    private function migration(): Migration
    {
        return require database_path('migrations/2026_11_27_000000_add_one_time_to_group_messages.php');
    }
}
