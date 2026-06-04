<?php

namespace Tests\Feature\Web\Backend;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * GET /admin/dashboard
 *
 * The smallest admin page. It renders `backend.layouts.dashboard`
 * with one variable: `totalUsers` (count of all users including the
 * admin themself). The middleware behavior is covered separately by
 * [[AdminMiddlewareTest]] — these tests assume admin auth is set up
 * and focus on the controller's own contract.
 */
class DashboardControllerTest extends TestCase
{
    use RefreshDatabase;

    /**
     * `backend.app` (the layout this view extends) calls `@vite(...)`,
     * which tries to load `public/build/manifest.json`. CI doesn't
     * build that manifest, so without `withoutVite()` the view render
     * throws `ViteManifestNotFoundException` and the response surfaces
     * as 500 instead of 200. Any admin-page test that goes through
     * the layout needs this.
     */
    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    /**
     * Returns 200, renders the dashboard view, and exposes a
     * `totalUsers` count matching User::count(). The count includes
     * the acting admin because the controller doesn't filter.
     */
    #[Test]
    public function dashboard_renders_with_total_users_count(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        User::factory()->count(3)->create();

        $resp = $this->actingAs($admin)->get('/admin/dashboard');

        $resp->assertOk()
            ->assertViewIs('backend.layouts.dashboard')
            ->assertViewHas('totalUsers', 4);
    }

    /**
     * Even with no other users, the view still receives totalUsers = 1
     * (the admin themself). Catches a regression where the controller
     * starts excluding admins or filtering by status.
     */
    #[Test]
    public function total_users_count_includes_the_acting_admin(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);

        $resp = $this->actingAs($admin)->get('/admin/dashboard');

        $resp->assertOk()
            ->assertViewHas('totalUsers', 1);
    }
}
