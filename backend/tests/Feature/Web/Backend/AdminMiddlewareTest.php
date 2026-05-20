<?php

namespace Tests\Feature\Web\Backend;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The `admin` middleware (App\Http\Middleware\AdminMiddleware) guards
 * every route mounted under the `/admin` prefix in routes/backend.php.
 *
 * Its contract:
 *   - guest                       → Laravel `auth` redirect to /login (302)
 *   - authenticated, role != admin → 403 with the JSON envelope shown below
 *   - authenticated, role == admin → request continues to the controller
 *
 * `/admin/dashboard` is used as the probe target because it is the
 * simplest admin route — any failure here is the middleware, not the
 * controller. Per-controller tests assume this contract holds and
 * skip re-asserting it for every endpoint.
 */
class AdminMiddlewareTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Hitting an admin route without an active session must redirect
     * to the login flow, not return JSON. The `web` middleware group
     * (sessions + auth) is what produces the redirect — the `admin`
     * middleware never runs in this case.
     */
    #[Test]
    public function guest_is_redirected_to_login(): void
    {
        $this->get('/admin/dashboard')
            ->assertStatus(302)
            ->assertRedirect('/login');
    }

    /**
     * A signed-in user with the default `role = user` must be blocked
     * by AdminMiddleware before reaching the controller. The middleware
     * returns a fixed JSON envelope (not a redirect, not a 401) — the
     * admin area treats role mismatch as an authorization failure.
     */
    #[Test]
    public function non_admin_user_receives_403_json(): void
    {
        $user = User::factory()->create(['role' => 'user']);

        $resp = $this->actingAs($user)->get('/admin/dashboard');

        $resp->assertStatus(403)
            ->assertJson([
                'status' => false,
                'message' => 'Unauthorized access. Role should be admin.',
                'code' => 403,
            ]);
    }

    /**
     * An admin user can pass the middleware. We only assert that we
     * did *not* get the 403/redirect — the actual dashboard rendering
     * is covered by DashboardControllerTest. This keeps the middleware
     * test orthogonal to the controller test.
     */
    #[Test]
    public function admin_user_is_allowed_through_the_middleware(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);

        $resp = $this->actingAs($admin)->get('/admin/dashboard');

        $this->assertNotEquals(403, $resp->status(), 'AdminMiddleware should have let an admin through.');
        $this->assertNotEquals(302, $resp->status(), 'AdminMiddleware should not redirect an authenticated admin.');
    }
}
