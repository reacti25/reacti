<?php

namespace Tests\Feature\Web\Backend\Settings;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins that the admin settings route groups (Profile, Firebase, Social,
 * General, DynamicPage) require auth + admin (backlog §1 / EP2).
 *
 * These groups previously relied solely on the `then:` closure in
 * bootstrap/app.php for their auth+admin middleware; they now also declare it
 * explicitly. Either way the contract — guest redirected, non-admin 403 — must
 * hold, so a future change to that closure can't silently expose them.
 */
class AdminSettingsRoutesProtectedTest extends TestCase
{
    use RefreshDatabase;

    /**
     * The GET landing route of each settings group, under the /admin prefix.
     *
     * @return array<string, array{string}>
     */
    public static function settingsRoutes(): array
    {
        return [
            'profile' => ['/admin/setting/profile'],
            'firebase' => ['/admin/setting/firebase'],
            'social' => ['/admin/setting/social'],
            'general' => ['/admin/setting/general'],
            'dynamic-page' => ['/admin/dynamic-page'],
        ];
    }

    #[Test]
    #[DataProvider('settingsRoutes')]
    public function guest_is_redirected_to_login(string $path): void
    {
        $this->get($path)
            ->assertStatus(302)
            ->assertRedirect('/login');
    }

    #[Test]
    #[DataProvider('settingsRoutes')]
    public function non_admin_user_is_forbidden(string $path): void
    {
        $user = User::factory()->create(['role' => 'user']);

        $this->actingAs($user)->get($path)->assertStatus(403);
    }
}
