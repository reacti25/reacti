<?php

namespace Tests\Feature\Database;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins the hard-delete policy (DG9): the users table has no `deleted_at`
 * column. Account deletion is permanent; the model never used SoftDeletes.
 */
class UsersNoSoftDeleteTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function users_table_has_no_deleted_at_column(): void
    {
        $this->assertFalse(
            Schema::hasColumn('users', 'deleted_at'),
            'users.deleted_at should be dropped — accounts are hard-deleted',
        );
    }
}
