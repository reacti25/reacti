<?php

namespace Tests\Feature\Web;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The unauthenticated maintenance routes (`/run-migrate-fresh`,
 * `/run-composer-update`, etc.) were removed: any anonymous visitor
 * could drop the production database or run `composer update` through
 * `shell_exec`. This test pins their absence so they cannot be
 * reintroduced unnoticed.
 */
class MaintenanceRoutesRemovedTest extends TestCase
{
    /**
     * The maintenance route paths that must no longer be registered.
     *
     * @return array<int, array{0: string}>
     */
    public static function maintenanceRoutes(): array
    {
        return [
            ['/run-migrate'],
            ['/run-migrate-fresh'],
            ['/run-composer-update'],
            ['/run-optimize-clear'],
            ['/run-db-seed'],
            ['/run-cache-clear'],
            ['/run-queue-restart'],
            ['/run-storage-link'],
        ];
    }

    #[Test]
    #[DataProvider('maintenanceRoutes')]
    public function maintenance_route_is_not_registered(string $path): void
    {
        $this->get($path)->assertNotFound();
    }
}
