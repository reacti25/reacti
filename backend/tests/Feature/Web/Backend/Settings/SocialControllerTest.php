<?php

namespace Tests\Feature\Web\Backend\Settings;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * SocialController — the Google OAuth settings page at
 * `/admin/setting/social*` (see routes/backend.php).
 *
 *   GET   /admin/setting/social         index
 *   PATCH /admin/setting/social/update  update
 *
 * `update` rewrites the `GOOGLE_*` lines in the project `.env`.
 * As with [[FirebaseControllerTest]], tests assert only the redirect
 * contract — the `.env` write is an environment side effect.
 */
class SocialControllerTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Boot the framework and disable Vite asset resolution.
     *
     * The admin views extend the `backend.app` Blade layout, which calls
     * `@vite`; `withoutVite()` stops that directive from failing when no
     * asset manifest has been built in the test environment.
     */
    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    /**
     * Create and return a freshly persisted user with the `admin` role.
     *
     * Used to authenticate requests against the admin-guarded `/admin/*`
     * routes exercised by these tests.
     *
     * @return User A persisted admin-role user.
     */
    private function admin(): User
    {
        return User::factory()->create(['role' => 'admin']);
    }

    /** `index` renders the `social_settings` Blade view with the `settings` view variable. */
    #[Test]
    public function index_renders_the_social_settings_view(): void
    {
        $this->actingAs($this->admin())->get('/admin/setting/social')
            ->assertOk()
            ->assertViewIs('backend.layouts.settings.social_settings')
            ->assertViewHas('settings');
    }

    /** `update` accepts the Google OAuth fields and answers with a 302 redirect. */
    #[Test]
    public function update_redirects_after_accepting_oauth_settings(): void
    {
        $this->actingAs($this->admin())->patch('/admin/setting/social/update', [
            'google_client_id'     => 'client-id-123',
            'google_client_secret' => 'client-secret-456',
            'google_redirect_url'  => 'https://example.com/callback',
        ])->assertStatus(302);
    }
}
