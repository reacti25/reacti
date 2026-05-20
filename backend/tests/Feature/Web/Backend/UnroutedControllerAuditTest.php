<?php

namespace Tests\Feature\Web\Backend;

use App\Http\Controllers\Web\Backend\EstablismentController;
use App\Http\Controllers\Web\Backend\Pages\PrivacyPolicyController;
use App\Http\Controllers\Web\Backend\PrivacyController;
use App\Http\Controllers\Web\Backend\SplashController;
use Illuminate\Support\Facades\Route;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Audit guard for the four `Web\Backend` controllers that exist in
 * the codebase but are wired to no route in routes/{web,backend,api}.php:
 *
 *   - Web\Backend\SplashController
 *   - Web\Backend\EstablismentController
 *   - Web\Backend\PrivacyController
 *   - Web\Backend\Pages\PrivacyPolicyController
 *
 * They cannot be feature-tested because there is no URL that reaches
 * them — so instead of HTTP tests, this audit pins their *unreachable*
 * status. The moment a route is added for any of them, the matching
 * test below fails. That failure is the signal to delete this entry
 * and write real per-endpoint coverage for the now-live controller.
 *
 * (Note: `App\Http\Controllers\Api\PrivacyController` — a different
 * class — *is* routed at GET /api/privacy-policy. This audit only
 * concerns the `Web\Backend` namespace.)
 *
 * Recorded in docs/testing/inventory.md §8.
 */
class UnroutedControllerAuditTest extends TestCase
{
    /**
     * Returns every controller class currently referenced by a
     * registered route (the `Controller@method` action string, minus
     * the method).
     *
     * @return list<string>
     */
    private function routedControllerClasses(): array
    {
        return collect(Route::getRoutes()->getRoutes())
            ->map(fn ($route) => $route->getActionName())
            ->filter(fn ($action) => is_string($action) && str_contains($action, '@'))
            ->map(fn ($action) => explode('@', $action, 2)[0])
            ->unique()
            ->values()
            ->all();
    }

    /** Asserts `Web\Backend\SplashController` is referenced by no registered route. */
    #[Test]
    public function splash_controller_is_unrouted(): void
    {
        $this->assertNotContains(
            SplashController::class,
            $this->routedControllerClasses(),
            'SplashController is now routed — add real coverage and drop this audit entry.',
        );
    }

    /** Asserts `Web\Backend\EstablismentController` is referenced by no registered route. */
    #[Test]
    public function establisment_controller_is_unrouted(): void
    {
        $this->assertNotContains(
            EstablismentController::class,
            $this->routedControllerClasses(),
            'EstablismentController is now routed — add real coverage and drop this audit entry.',
        );
    }

    /** Asserts `Web\Backend\PrivacyController` is referenced by no registered route. */
    #[Test]
    public function backend_privacy_controller_is_unrouted(): void
    {
        $this->assertNotContains(
            PrivacyController::class,
            $this->routedControllerClasses(),
            'Web\\Backend\\PrivacyController is now routed — add real coverage and drop this audit entry.',
        );
    }

    /** Asserts `Web\Backend\Pages\PrivacyPolicyController` is referenced by no registered route. */
    #[Test]
    public function backend_privacy_policy_page_controller_is_unrouted(): void
    {
        $this->assertNotContains(
            PrivacyPolicyController::class,
            $this->routedControllerClasses(),
            'Pages\\PrivacyPolicyController is now routed — add real coverage and drop this audit entry.',
        );
    }
}
