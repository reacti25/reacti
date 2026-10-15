<?php

namespace Tests\Feature\Web;

use App\Models\DynamicPage;
use App\Models\User;
use Database\Seeders\UserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Three problems found on 2026-10-15 while publishing the new privacy policy:
 * the admin page list failed with "Ajax error", the public privacy page showed
 * a stale hardcoded date, and the admin seeder shipped the password 12345678
 * (which was live on production).
 */
class AdminDefaultsAndPagesTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function admin_page_list_loads_when_content_has_multibyte_characters(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        // An em dash straddling byte 100: substr() cut it in half, the JSON
        // reply failed to encode, and DataTables showed "Ajax error".
        DynamicPage::create([
            'page_title' => 'Privacy Policy',
            'page_slug' => 'privacy-policy',
            'page_content' => '<h1>'.str_repeat('a', 95).'—— long text ’ שלום</h1>',
            'status' => 'active',
        ]);

        $response = $this->actingAs($admin)
            ->withHeader('X-Requested-With', 'XMLHttpRequest')
            ->getJson('/admin/dynamic-page?draw=1&start=0&length=10');

        $response->assertOk();
        $preview = $response->json('data.0.page_content');
        $this->assertTrue(mb_check_encoding($preview, 'UTF-8'));
        $this->assertStringNotContainsString('<h1>', $preview);
    }

    #[Test]
    public function public_privacy_page_has_no_hardcoded_date(): void
    {
        DynamicPage::create([
            'page_title' => 'Privacy Policy',
            'page_slug' => 'privacy-policy',
            'page_content' => '<p>Last updated: October 15, 2026</p>',
            'status' => 'active',
        ]);

        $this->get('/privacy-policy')
            ->assertOk()
            ->assertSee('October 15, 2026')
            ->assertDontSee('November 28, 2024');
    }

    #[Test]
    public function seeded_admin_never_gets_the_old_default_password_or_a_real_email(): void
    {
        $this->seed(UserSeeder::class);

        $admin = User::where('role', 'admin')->firstOrFail();
        $this->assertFalse(Hash::check('12345678', $admin->password));
        $this->assertSame('admin@reacti.test', $admin->email);
    }
}
