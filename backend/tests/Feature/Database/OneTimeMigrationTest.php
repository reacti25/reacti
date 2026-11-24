<?php

namespace Tests\Feature\Database;

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins that the one-time media migration runs on a server that still has the
 * bare `chats.one_time` column the July 2026 attempt left behind.
 *
 * Staging was such a server: the first version of the migration stopped with
 * "Duplicate column name 'one_time'" on 2026-11-24 and the deploy failed
 * half way, with the new code live and `one_time_opened_at` missing.
 */
class OneTimeMigrationTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function it_finishes_on_a_table_that_already_has_the_old_one_time_column(): void
    {
        $migration = $this->oneTimeMigration();
        $migration->down();
        // What the July migration left: the flag alone, no index, no stamp.
        Schema::table('chats', fn (Blueprint $table) => $table->boolean('one_time')->default(false));

        $migration->up();

        $this->assertTrue(Schema::hasColumn('chats', 'one_time'));
        $this->assertTrue(Schema::hasIndex('chats', ['one_time']));
        $this->assertTrue(Schema::hasColumn('chats', 'one_time_opened_at'));
    }

    #[Test]
    public function running_it_twice_changes_nothing_and_does_not_fail(): void
    {
        $this->oneTimeMigration()->up();

        $this->assertTrue(Schema::hasIndex('chats', ['one_time']));
        $this->assertTrue(Schema::hasColumn('chats', 'one_time_opened_at'));
    }

    /** The migration under test, loaded from its file. */
    private function oneTimeMigration(): Migration
    {
        return require database_path('migrations/2026_11_24_000000_add_one_time_to_chats.php');
    }
}
