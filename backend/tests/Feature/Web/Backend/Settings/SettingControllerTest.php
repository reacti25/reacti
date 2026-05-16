<?php

namespace Tests\Feature\Web\Backend\Settings;

use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * SettingController — the general site-settings page at
 * `/admin/setting/general` (see routes/backend.php).
 *
 *   GET   /admin/setting/general  index
 *   PATCH /admin/setting/general  update
 *
 * Unlike the Firebase/Social settings, this one persists to the
 * `settings` table (a single row, id = 1) rather than to `.env`, so
 * the update test can assert real database state.
 */
class SettingControllerTest extends TestCase
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

    /** Renders even when no settings row exists yet (the common first-run case). */
    #[Test]
    public function index_renders_the_general_settings_view(): void
    {
        $this->actingAs($this->admin())->get('/admin/setting/general')
            ->assertOk()
            ->assertViewIs('backend.layouts.settings.general_settings');
    }

    /** `update` upserts the single settings row (id = 1) and redirects. */
    #[Test]
    public function update_persists_the_settings_row(): void
    {
        $this->actingAs($this->admin())->patch('/admin/setting/general', [
            'name'      => 'Reacti',
            'email'     => 'hello@reacti.io',
            'copyright' => '(c) 2026 Reacti',
        ])->assertStatus(302);

        $this->assertDatabaseHas('settings', [
            'id'    => 1,
            'name'  => 'Reacti',
            'email' => 'hello@reacti.io',
        ]);
    }

    /** A second update edits the same row rather than inserting a new one. */
    #[Test]
    public function update_edits_the_existing_row_instead_of_inserting(): void
    {
        Setting::create(['id' => 1, 'name' => 'Old Name']);

        $this->actingAs($this->admin())->patch('/admin/setting/general', [
            'name' => 'New Name',
        ])->assertStatus(302);

        $this->assertDatabaseCount('settings', 1);
        $this->assertDatabaseHas('settings', ['id' => 1, 'name' => 'New Name']);
    }
}
