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

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    private function admin(): User
    {
        return User::factory()->create(['role' => 'admin']);
    }

    #[Test]
    public function index_renders_the_social_settings_view(): void
    {
        $this->actingAs($this->admin())->get('/admin/setting/social')
            ->assertOk()
            ->assertViewIs('backend.layouts.settings.social_settings')
            ->assertViewHas('settings');
    }

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
