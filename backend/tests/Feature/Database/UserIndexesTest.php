<?php

namespace Tests\Feature\Database;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins that the users.role and users.status columns are indexed
 * (backlog §4 / EP5).
 */
class UserIndexesTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function role_and_status_columns_are_indexed(): void
    {
        $indexedColumns = collect(Schema::getIndexes('users'))
            ->flatMap(fn (array $index) => $index['columns'])
            ->unique()
            ->all();

        $this->assertContains('role', $indexedColumns);
        $this->assertContains('status', $indexedColumns);
    }
}
