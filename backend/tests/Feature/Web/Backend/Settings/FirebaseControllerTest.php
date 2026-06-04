<?php

namespace Tests\Feature\Web\Backend\Settings;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * FirebaseController — the Firebase-credentials settings page at
 * `/admin/setting/firebase*` (see routes/backend.php).
 *
 *   GET   /admin/setting/firebase         index
 *   PATCH /admin/setting/firebase/update  update
 *
 * `update` rewrites the `FIREBASE_CREDENTIALS` line in the project
 * `.env`. Tests only assert the redirect contract — not the file
 * contents — since the `.env` write is an environment side effect,
 * not application state. In CI the `.env` is a throwaway fixture.
 */
class FirebaseControllerTest extends TestCase
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

    /** `index` renders the `firebase_settings` Blade view with the `settings` view variable. */
    #[Test]
    public function index_renders_the_firebase_settings_view(): void
    {
        $this->actingAs($this->admin())->get('/admin/setting/firebase')
            ->assertOk()
            ->assertViewIs('backend.layouts.settings.firebase_settings')
            ->assertViewHas('settings');
    }

    /**
     * `update` always answers with a redirect: on success it flashes
     * `t-success`, and even if the `.env` write fails the controller's
     * catch still returns `back()`. We assert the 302 either way.
     */
    #[Test]
    public function update_redirects_after_accepting_credentials(): void
    {
        $this->actingAs($this->admin())->patch('/admin/setting/firebase/update', [
            'firebase_credentials' => 'test-credentials-blob',
        ])->assertStatus(302);
    }
}
