<?php

namespace Tests\Feature\Web\Backend\Settings;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * ProfileController — the admin's own account settings, mounted at
 * `/admin/setting/profile*` (see routes/backend.php).
 *
 *   GET  /admin/setting/profile               index
 *   PUT  /admin/setting/profile/update        UpdateProfile
 *   PUT  /admin/setting/profile/update/Password  UpdatePassword
 *   POST /admin/setting/profile/update/Picture   UpdateProfilePicture
 *
 * Admin-middleware behavior is covered once by [[AdminMiddlewareTest]].
 */
class ProfileControllerTest extends TestCase
{
    use RefreshDatabase;

    /** Settings views extend `backend.app`, which pulls in @vite. */
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
    public function index_renders_the_profile_settings_view(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)->get('/admin/setting/profile?id=' . $admin->id)
            ->assertOk()
            ->assertViewIs('backend.layouts.settings.profile_settings');
    }

    /**
     * KNOWN BUG (documented, not fixed — testing-only scope).
     *
     * `UpdateProfile` assigns `$user->name`, but the `users` table has
     * no `name` column (it uses `first_name` / `last_name`). Saving
     * therefore throws a QueryException, which the controller swallows
     * in its `catch` and turns into a redirect with a `t-error` flash.
     *
     * Net effect: the endpoint never actually updates anything but
     * still answers 302. This test pins that observable behavior; the
     * fix is to assign `first_name` / `last_name`. Flagged in
     * inventory.md §8.
     */
    #[Test]
    public function update_profile_redirects_but_cannot_persist_due_to_the_name_column_bug(): void
    {
        $admin = $this->admin();

        $resp = $this->actingAs($admin)->put('/admin/setting/profile/update', [
            'email' => 'fresh-admin@example.com',
        ]);

        $resp->assertStatus(302);
        // The save throws before email is committed, so nothing changed.
        $this->assertDatabaseMissing('users', ['email' => 'fresh-admin@example.com']);
    }

    /** Correct current password → the password hash is replaced. */
    #[Test]
    public function update_password_changes_the_hash_with_a_correct_current_password(): void
    {
        $admin = $this->admin(); // factory password is 'password'

        $this->actingAs($admin)->put('/admin/setting/profile/update/Password', [
            'old_password'          => 'password',
            'password'              => 'brand-new-secret',
            'password_confirmation' => 'brand-new-secret',
        ])->assertStatus(302);

        $this->assertTrue(Hash::check('brand-new-secret', $admin->fresh()->password));
    }

    /** Wrong current password → the hash is left untouched. */
    #[Test]
    public function update_password_rejects_a_wrong_current_password(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)->put('/admin/setting/profile/update/Password', [
            'old_password'          => 'not-the-password',
            'password'              => 'brand-new-secret',
            'password_confirmation' => 'brand-new-secret',
        ])->assertStatus(302);

        $this->assertTrue(Hash::check('password', $admin->fresh()->password));
    }

    /** A new password under 8 chars fails validation. */
    #[Test]
    public function update_password_enforces_the_minimum_length(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)->put('/admin/setting/profile/update/Password', [
            'old_password'          => 'password',
            'password'              => 'short',
            'password_confirmation' => 'short',
        ])->assertSessionHasErrors('password');

        $this->assertTrue(Hash::check('password', $admin->fresh()->password));
    }

    /** Posting the picture endpoint with no file fails validation. */
    #[Test]
    public function update_profile_picture_requires_an_avatar_file(): void
    {
        $this->actingAs($this->admin())
            ->postJson('/admin/setting/profile/update/Picture', [])
            ->assertStatus(422);
    }
}
