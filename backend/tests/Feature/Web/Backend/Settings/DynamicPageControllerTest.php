<?php

namespace Tests\Feature\Web\Backend\Settings;

use App\Models\DynamicPage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * DynamicPageController — CMS pages (privacy policy, terms, etc.)
 * managed under `/admin/dynamic-page*` (see routes/backend.php).
 *
 *   GET    /admin/dynamic-page             index   (Blade list view)
 *   GET    /admin/dynamic-page/create      create
 *   POST   /admin/dynamic-page/store       store
 *   GET    /admin/dynamic-page/edit/{id}   edit
 *   PUT    /admin/dynamic-page/update/{id} update
 *   POST   /admin/dynamic-page/status/{id} status  (JSON toggle)
 *   DELETE /admin/dynamic-page/destroy/{id} destroy (JSON)
 *
 * `index` doubles as a Yajra DataTables JSON source when the request
 * is ajax; these tests exercise the plain (non-ajax) Blade path.
 */
class DynamicPageControllerTest extends TestCase
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

    /** `index` (non-ajax) renders the `dynamic_page.index` Blade list view. */
    #[Test]
    public function index_renders_the_dynamic_page_list_view(): void
    {
        $this->actingAs($this->admin())->get('/admin/dynamic-page')
            ->assertOk()
            ->assertViewIs('backend.layouts.settings.dynamic_page.index');
    }

    /** `create` renders the `dynamic_page.create` Blade form view. */
    #[Test]
    public function create_renders_the_create_form_view(): void
    {
        $this->actingAs($this->admin())->get('/admin/dynamic-page/create')
            ->assertOk()
            ->assertViewIs('backend.layouts.settings.dynamic_page.create');
    }

    /**
     * `store` persists a page, derives the slug from the title, and
     * defaults the status to `active`.
     */
    #[Test]
    public function store_creates_a_dynamic_page_with_a_slug(): void
    {
        $this->actingAs($this->admin())->post('/admin/dynamic-page/store', [
            'page_title' => 'Privacy Policy',
            'page_content' => 'The full policy text.',
        ])->assertStatus(302);

        $this->assertDatabaseHas('dynamic_pages', [
            'page_title' => 'Privacy Policy',
            'page_slug' => 'privacy-policy',
            'page_content' => 'The full policy text.',
            'status' => 'active',
        ]);
    }

    /** `store` requires both a title and content. */
    #[Test]
    public function store_validates_required_fields(): void
    {
        $this->actingAs($this->admin())->post('/admin/dynamic-page/store', [])
            ->assertSessionHasErrors(['page_title', 'page_content']);

        $this->assertDatabaseCount('dynamic_pages', 0);
    }

    /** `edit` renders the `dynamic_page.edit` view with the page passed as the `data` view variable. */
    #[Test]
    public function edit_renders_the_edit_view_with_the_page(): void
    {
        $page = DynamicPage::create([
            'page_title' => 'Terms',
            'page_slug' => 'terms',
            'page_content' => 'Terms text.',
            'status' => 'active',
        ]);

        $this->actingAs($this->admin())->get("/admin/dynamic-page/edit/{$page->id}")
            ->assertOk()
            ->assertViewIs('backend.layouts.settings.dynamic_page.edit')
            ->assertViewHas('data');
    }

    /** `update` rewrites the page content and redirects to the list. */
    #[Test]
    public function update_changes_the_page_content(): void
    {
        $page = DynamicPage::create([
            'page_title' => 'Terms',
            'page_slug' => 'terms',
            'page_content' => 'Old text.',
            'status' => 'active',
        ]);

        $this->actingAs($this->admin())->put("/admin/dynamic-page/update/{$page->id}", [
            'page_content' => 'Updated text.',
        ])->assertStatus(302);

        $this->assertDatabaseHas('dynamic_pages', [
            'id' => $page->id,
            'page_content' => 'Updated text.',
        ]);
    }

    /**
     * `status` toggles the publish flag. Starting from `active` it
     * flips to `inactive` and reports `success: false` (the JSON
     * `success` key tracks the *new published state*, not the request
     * outcome).
     */
    #[Test]
    public function status_toggles_an_active_page_to_inactive(): void
    {
        $page = DynamicPage::create([
            'page_title' => 'Terms',
            'page_slug' => 'terms',
            'page_content' => 'Terms text.',
            'status' => 'active',
        ]);

        $this->actingAs($this->admin())->post("/admin/dynamic-page/status/{$page->id}")
            ->assertOk()
            ->assertJsonPath('success', false);

        $this->assertDatabaseHas('dynamic_pages', [
            'id' => $page->id,
            'status' => 'inactive',
        ]);
    }

    /** From `inactive`, the same endpoint flips back to `active`. */
    #[Test]
    public function status_toggles_an_inactive_page_to_active(): void
    {
        $page = DynamicPage::create([
            'page_title' => 'Terms',
            'page_slug' => 'terms',
            'page_content' => 'Terms text.',
            'status' => 'inactive',
        ]);

        $this->actingAs($this->admin())->post("/admin/dynamic-page/status/{$page->id}")
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertDatabaseHas('dynamic_pages', [
            'id' => $page->id,
            'status' => 'active',
        ]);
    }

    /** `destroy` removes the page row and answers with JSON. */
    #[Test]
    public function destroy_deletes_the_page(): void
    {
        $page = DynamicPage::create([
            'page_title' => 'Terms',
            'page_slug' => 'terms',
            'page_content' => 'Terms text.',
            'status' => 'active',
        ]);

        $this->actingAs($this->admin())->deleteJson("/admin/dynamic-page/destroy/{$page->id}")
            ->assertOk()
            ->assertJsonPath('t-success', true);

        $this->assertDatabaseMissing('dynamic_pages', ['id' => $page->id]);
    }
}
