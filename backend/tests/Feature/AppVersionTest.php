<?php

namespace Tests\Feature;

use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The update prompt's source: GET /api/app-version answers the newest app
 * version per platform (the admin settings first, then the environment) and
 * where to update; the admin settings page stores and checks the versions.
 */
class AppVersionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        config([
            'reacti.latest_version.ios' => null,
            'reacti.latest_version.android' => null,
        ]);
    }

    /** Nothing set anywhere: no version (no prompt), store links still there. */
    #[Test]
    public function with_nothing_set_there_is_no_version(): void
    {
        $this->getJson('/api/app-version')
            ->assertOk()
            ->assertJsonPath('data.ios.latest_version', null)
            ->assertJsonPath('data.android.latest_version', null)
            ->assertJsonPath('data.ios.update_url', 'https://apps.apple.com/app/id6755814897')
            ->assertJsonPath('data.android.update_url', 'https://play.google.com/store/apps/details?id=com.reacti.app');
    }

    /** The environment's versions are used while the settings are empty. */
    #[Test]
    public function the_environment_fills_in_for_empty_settings(): void
    {
        config(['reacti.latest_version.ios' => '1.8.4', 'reacti.update_url.ios' => 'itms-beta://']);
        Setting::create(['id' => 1, 'name' => 'Reacti']);

        $this->getJson('/api/app-version')
            ->assertJsonPath('data.ios.latest_version', '1.8.4')
            ->assertJsonPath('data.ios.update_url', 'itms-beta://')
            ->assertJsonPath('data.android.latest_version', null);
    }

    /** What the admin typed wins over the environment. */
    #[Test]
    public function the_admin_settings_win(): void
    {
        config(['reacti.latest_version.android' => '1.0.0']);
        Setting::create(['id' => 1, 'latest_ios_version' => '1.9.0', 'latest_android_version' => '1.9.1']);

        $this->getJson('/api/app-version')
            ->assertJsonPath('data.ios.latest_version', '1.9.0')
            ->assertJsonPath('data.android.latest_version', '1.9.1');
    }

    /** The admin settings page stores the versions and refuses anything that is not one. */
    #[Test]
    public function the_admin_page_stores_the_versions(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);

        $this->actingAs($admin)->patch('/admin/setting/general', [
            'latest_ios_version' => '1.9.0',
            'latest_android_version' => '1.9',
        ])->assertSessionHasNoErrors();
        $this->assertDatabaseHas('settings', ['id' => 1, 'latest_ios_version' => '1.9.0', 'latest_android_version' => '1.9']);

        $this->actingAs($admin)->patch('/admin/setting/general', [
            'latest_ios_version' => 'v1.9 beta',
        ])->assertSessionHasErrors('latest_ios_version');
        $this->actingAs($admin)->get('/admin/setting/general')->assertOk()->assertSee('Latest iPhone version');
    }
}
